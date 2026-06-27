"""
Curated catalogue of common SDR profiles that can be bulk-added to a device from
the SDR device settings page.

Each preset is a plain dict using the same keys as a stored profile:
  name, center_freq, samp_rate (Hz), start_freq (Hz), start_mod, tuning_step.

Only always-available analog modulations are used (nfm/am/usb/lsb/wfm) so that a
created profile is always valid regardless of which optional decoders are
installed - the digital decoders (FT8, APRS, ...) still run as background
services on top of these. Sample rates are kept at 2.4 MS/s, the reliable RTL-SDR
maximum, so the presets work on RTL-SDR as well as SDRplay.

Frequencies are the conventional Region 2 / North American dial frequencies
(FT8 dial freqs per the WSJT-X defaults). Groups let the user pick a set that
matches their device: VHF/UHF presets work on any RTL-SDR; HF presets need an
HF-capable receiver (SDRplay, or an RTL-SDR V4 / upconverter).
"""


def _hfBand(name, center_khz, ft8_khz):
    # one profile per HF band, centred mid-band and opening on the FT8 dial
    # (FT8 is USB on every band); the user can retune to SSB/CW/WSPR within it.
    return {
        "name": name,
        "center_freq": int(center_khz * 1000),
        "samp_rate": 2400000,
        "start_freq": int(ft8_khz * 1000),
        "start_mod": "usb",
        "tuning_step": "100",
    }


VHF_UHF = [
    {"name": "2m APRS", "center_freq": 145000000, "samp_rate": 2400000,
     "start_freq": 144390000, "start_mod": "nfm", "tuning_step": "1"},
    {"name": "2m FM (calling/repeaters)", "center_freq": 146000000, "samp_rate": 2400000,
     "start_freq": 146520000, "start_mod": "nfm", "tuning_step": "5000"},
    {"name": "2m SSB / FT8", "center_freq": 144200000, "samp_rate": 2400000,
     "start_freq": 144174000, "start_mod": "usb", "tuning_step": "100"},
    {"name": "70cm FM", "center_freq": 445000000, "samp_rate": 2400000,
     "start_freq": 446000000, "start_mod": "nfm", "tuning_step": "12500"},
    {"name": "Airband (AM)", "center_freq": 127000000, "samp_rate": 2400000,
     "start_freq": 127000000, "start_mod": "am", "tuning_step": "8330"},
    {"name": "Marine VHF", "center_freq": 157000000, "samp_rate": 2400000,
     "start_freq": 156800000, "start_mod": "nfm", "tuning_step": "25000"},
    {"name": "NWS Weather", "center_freq": 162450000, "samp_rate": 2400000,
     "start_freq": 162550000, "start_mod": "nfm", "tuning_step": "25000"},
    {"name": "Broadcast FM", "center_freq": 98000000, "samp_rate": 2400000,
     "start_freq": 98000000, "start_mod": "wfm", "tuning_step": "100000"},
]

HF = [
    _hfBand("160m", 1900, 1840),
    _hfBand("80m", 3700, 3573),
    _hfBand("60m", 5360, 5357),
    _hfBand("40m", 7150, 7074),
    _hfBand("30m", 10130, 10136),
    _hfBand("20m", 14150, 14074),
    _hfBand("17m", 18110, 18100),
    _hfBand("15m", 21150, 21074),
    _hfBand("12m", 24930, 24915),
    _hfBand("10m", 28500, 28074),
]


class ProfilePresets(object):
    # ordered: key -> (label, list-of-presets)
    groups = {
        "vhfuhf": ("Common VHF/UHF (any RTL-SDR)", VHF_UHF),
        "hf": ("HF bands (SDRplay / RTL-SDR V4)", HF),
        "all": ("All of the above", VHF_UHF + HF),
    }

    @staticmethod
    def getGroupOptions():
        # [(key, label), ...] for building a dropdown
        return [(key, label) for key, (label, _) in ProfilePresets.groups.items()]

    @staticmethod
    def getProfiles(key):
        group = ProfilePresets.groups.get(key)
        return list(group[1]) if group is not None else []
