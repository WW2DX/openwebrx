from owrx.reporting.reporter import Reporter
from owrx.config import Config
from owrx.bands import Bandplan
from queue import Queue, Full
from urllib import request
import json
import math
import socket
import threading
import logging

logger = logging.getLogger(__name__)

# Hostname of the machine running this receiver. Prepended to every Slack
# message so that, when several OpenWebRX listeners report to the same channel,
# each spot can be attributed to the station that decoded it. Resolved once at
# import time since it does not change while the process runs.
hostname = socket.gethostname()


# Modes that can produce spots reaching the reporting engine. Used to populate
# the mode selector on the "Spotting and reporting" settings page. These are the
# exact strings that appear as spot["mode"] (emitted by the various decoders),
# NOT the modulation identifiers from owrx.modes - e.g. APRS rides on the
# "packet" modulation but is reported with mode "APRS".
SLACK_SPOTTABLE_MODES = [
    "APRS",
    "AIS",
    "FT8",
    "FT4",
    "JT65",
    "JT9",
    "WSPR",
    "FST4",
    "FST4W",
    "Q65",
    "JS8",
    "SONDE",
    "CW",
    "RTTY",
]

# Pseudo-modes the reporting engine emits for server/receiver status rather than
# actual decodes (server startup, SDR profile changes, database refreshes). These
# are never DX spots and must not be forwarded to Slack, even when the user's mode
# filter is empty ("all modes").
IGNORED_MODES = {"RX"}


class SlackReporter(Reporter):
    """Posts decoded spots to a Slack incoming webhook.

    Which spots are sent is controlled by two optional filters configured in the
    "Spotting and reporting" settings page:
      - slack_modes: only send spots whose mode is in this list (empty = all)
      - slack_bands: only send spots whose frequency falls in one of these bands
        (empty = all). The band is derived from the spot frequency via the
        Bandplan, since spots do not carry a band name themselves.

    Sending happens on a dedicated worker thread so a slow or unreachable webhook
    never blocks the decoding/reporting path.
    """

    def __init__(self):
        self.configLock = threading.Lock()
        self.queue = Queue(100)
        self.doRun = True
        self._readConfig()
        pm = Config.get()
        self.subscriptions = [
            pm.filter(
                "slack_webhook_url",
                "slack_modes",
                "slack_bands",
                "slack_station_name",
                "receiver_gps",
            ).wire(self._readConfig)
        ]
        self.worker = threading.Thread(target=self._sendLoop, name="SlackReporter", daemon=True)
        self.worker.start()

    def _readConfig(self, *args):
        pm = Config.get()
        with self.configLock:
            self.url = pm["slack_webhook_url"] if "slack_webhook_url" in pm else ""
            self.modes = pm["slack_modes"] if "slack_modes" in pm else []
            self.bands = pm["slack_bands"] if "slack_bands" in pm else []
            self.stationName = pm["slack_station_name"] if "slack_station_name" in pm else ""
            self.rxLocation = self._readReceiverLocation(pm)

    @staticmethod
    def _readReceiverLocation(pm):
        # receiver_gps is a PropertyLayer with lat/lon; treat the unset 0,0
        # placeholder as "no location" so we don't emit nonsensical distances.
        try:
            gps = pm["receiver_gps"]
            lat, lon = gps["lat"], gps["lon"]
        except (KeyError, TypeError):
            return None
        if lat == 0 and lon == 0:
            return None
        return (lat, lon)

    def spot(self, spot):
        with self.configLock:
            url = self.url
            modes = self.modes
            bands = self.bands

        if not url:
            return

        # never forward server/receiver status reports, only real decodes
        if spot.get("mode") in IGNORED_MODES:
            return

        # mode filter: an empty list means "all modes"
        if modes and spot.get("mode") not in modes:
            return

        # band filter: an empty list means "all bands"
        if bands and self._getBandName(spot) not in bands:
            return

        try:
            self.queue.put(spot, block=False)
        except Full:
            logger.warning("Slack webhook queue overflow, dropping spot")

    def _getBandName(self, spot):
        freq = spot.get("freq")
        if not freq:
            return None
        band = Bandplan.getSharedInstance().findBand(freq)
        return band.getName() if band is not None else None

    # 16-point compass for human-readable azimuth
    _COMPASS = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]

    def _spotLatLon(self, spot):
        # explicit position (APRS/AIS/SONDE) takes precedence; otherwise fall
        # back to a Maidenhead locator (FT8/WSPR/JS8 carry a grid, not lat/lon).
        if "lat" in spot and "lon" in spot:
            return (spot["lat"], spot["lon"])
        if spot.get("locator"):
            return self._gridToLatLon(spot["locator"])
        return None

    @staticmethod
    def _gridToLatLon(grid):
        # decode a Maidenhead locator to the lat/lon of the square's center
        g = grid.strip()
        if len(g) < 4:
            return None
        try:
            lon = (ord(g[0].upper()) - ord("A")) * 20.0 - 180.0
            lat = (ord(g[1].upper()) - ord("A")) * 10.0 - 90.0
            lon += int(g[2]) * 2.0
            lat += int(g[3]) * 1.0
            if len(g) >= 6:
                lon += (ord(g[4].upper()) - ord("A")) * (2.0 / 24.0) + (2.0 / 24.0) / 2
                lat += (ord(g[5].upper()) - ord("A")) * (1.0 / 24.0) + (1.0 / 24.0) / 2
            else:
                lon += 1.0   # center of the 2-degree-wide square
                lat += 0.5   # center of the 1-degree-tall square
        except (ValueError, IndexError):
            return None
        return (lat, lon)

    @staticmethod
    def _distanceKm(p1, p2):
        # haversine great-circle distance in km (matches owrx.web.repeaters)
        earthR = 6371
        rlat1 = p1[0] * (math.pi / 180)
        rlat2 = p2[0] * (math.pi / 180)
        difflat = rlat2 - rlat1
        difflon = (p2[1] - p1[1]) * (math.pi / 180)
        return round(2 * earthR * math.asin(math.sqrt(
            math.sin(difflat / 2) ** 2 +
            math.cos(rlat1) * math.cos(rlat2) * math.sin(difflon / 2) ** 2
        )))

    @staticmethod
    def _bearing(p1, p2):
        # initial great-circle bearing in degrees (matches owrx.aircraft.manager)
        d = (p2[1] - p1[1]) * math.pi / 180
        pr1 = p1[0] * math.pi / 180
        pr2 = p2[0] * math.pi / 180
        y = math.sin(d) * math.cos(pr2)
        x = math.cos(pr1) * math.sin(pr2) - math.sin(pr1) * math.cos(pr2) * math.cos(d)
        return (math.atan2(y, x) * 180 / math.pi + 360) % 360

    @staticmethod
    def _compass(azimuth):
        return SlackReporter._COMPASS[int(azimuth / 22.5 + 0.5) % 16]

    def _sendLoop(self):
        while self.doRun:
            spot = self.queue.get()
            try:
                if spot is not None:
                    self._send(spot)
            except Exception:
                logger.exception("error sending spot to Slack webhook")
            finally:
                self.queue.task_done()

    def _send(self, spot):
        with self.configLock:
            url = self.url
        if not url:
            return
        payload = {"text": self._formatMessage(spot)}
        data = json.dumps(payload).encode("utf-8")
        req = request.Request(
            url, data=data, headers={"Content-Type": "application/json"}, method="POST"
        )
        with request.urlopen(req, timeout=10) as response:
            response.read()

    def _formatMessage(self, spot):
        # use the configured station name, falling back to the machine hostname
        label = getattr(self, "stationName", "") or hostname
        parts = ["[{}]".format(label), "*{}*".format(spot.get("mode", "?"))]

        identifier = spot.get("source") or spot.get("callsign")
        if identifier:
            parts.append(str(identifier))

        freq = spot.get("freq")
        if freq:
            band = self._getBandName(spot)
            if band:
                parts.append("on {} ({:.4f} MHz)".format(band, freq / 1e6))
            else:
                parts.append("on {:.4f} MHz".format(freq / 1e6))

        if "lat" in spot and "lon" in spot:
            parts.append("at {:.5f},{:.5f}".format(spot["lat"], spot["lon"]))
        elif spot.get("locator"):
            parts.append("grid {}".format(spot["locator"]))

        # distance and azimuth from the receiver to the spot, when both known
        rx = getattr(self, "rxLocation", None)
        spotLoc = self._spotLatLon(spot)
        if rx and spotLoc:
            az = self._bearing(rx, spotLoc)
            parts.append("· {} km {:.0f}° {}".format(self._distanceKm(rx, spotLoc), az, self._compass(az)))

        text = spot.get("comment") or spot.get("message") or spot.get("msg")
        if text:
            parts.append("— {}".format(text))

        return " ".join(parts)

    def stop(self):
        self.doRun = False
        # unblock the worker thread if it is waiting on an empty queue
        try:
            self.queue.put(None, block=False)
        except Full:
            pass
        while self.subscriptions:
            self.subscriptions.pop().cancel()
