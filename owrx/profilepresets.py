"""
Curated catalogue of common SDR profiles that can be bulk-added to a device from
the SDR device settings page ("Add common profiles").

Each preset is a plain dict using the same keys as a stored profile:
  name, center_freq, samp_rate (Hz), start_freq (Hz), start_mod, tuning_step.

Only always-available analog modulations are used (nfm/am/usb/lsb/wfm) as the
opening mode - exactly like the built-in default profiles, where even the ADS-B
profile opens in nfm. The digital decoders (FT8, APRS, ADS-B, ACARS, ...) are
selected on top of these once tuned. Sample rate is 2.4 MS/s, the reliable
RTL-SDR maximum, so the presets work on RTL-SDR as well as SDRplay.

Frequencies are conventional North American / Region 2 dial frequencies. Groups
let the user pick a set that matches their hardware: VHF/UHF presets work on any
RTL-SDR; HF presets need an HF-capable receiver (SDRplay, or an RTL-SDR V4 /
upconverter); L-band presets need ~1.5-1.7 GHz coverage.
"""

SR = 2400000  # default sample rate: the reliable RTL-SDR maximum


def P(name, center_khz, start_khz, mod, step="100"):
    # frequencies given in kHz (ints) to avoid floating point rounding
    return {
        "name": name,
        "center_freq": center_khz * 1000,
        "samp_rate": SR,
        "start_freq": start_khz * 1000,
        "start_mod": mod,
        "tuning_step": step,
    }


# --- VHF/UHF: works on any RTL-SDR -------------------------------------------
VHF_UHF = [
    P("2m APRS", 145000, 144390, "nfm", "1"),
    P("2m FM (calling/repeaters)", 146000, 146520, "nfm", "5000"),
    P("2m SSB / FT8", 144200, 144174, "usb", "100"),
    P("1.25m (222 MHz)", 223500, 223500, "nfm", "5000"),
    P("70cm FM", 445000, 446000, "nfm", "12500"),
    P("70cm SSB / FT8", 432200, 432174, "usb", "100"),
    P("6m (FT8/SSB)", 50200, 50313, "usb", "100"),
    P("Airband (AM)", 127000, 127000, "am", "8330"),
    P("Marine VHF", 157000, 156800, "nfm", "25000"),
    P("NWS Weather", 162450, 162550, "nfm", "25000"),
    P("Broadcast FM", 98000, 98000, "wfm", "100000"),
    P("433 MHz ISM", 433920, 433920, "nfm", "25000"),
    P("Meshtastic 433 (EU)", 433875, 433875, "nfm", "25000"),
    P("Meshtastic 915 (US)", 906875, 906875, "nfm", "25000"),
    P("MeshCore 868 (EU)", 869618, 869618, "nfm", "25000"),
    P("MeshCore 915 (US)", 910525, 910525, "nfm", "25000"),
    P("1090 MHz ADS-B", 1090000, 1090000, "nfm", "25000"),
]

# --- HF amateur bands: need an HF-capable receiver ---------------------------
# one profile per band, centred mid-band, opening on the FT8 dial (USB)
HF = [
    P("160m", 1900, 1840, "usb", "100"),
    P("80m", 3700, 3573, "usb", "100"),
    P("60m", 5360, 5357, "usb", "100"),
    P("40m", 7150, 7074, "usb", "100"),
    P("30m", 10130, 10136, "usb", "100"),
    P("20m", 14150, 14074, "usb", "100"),
    P("17m", 18110, 18100, "usb", "100"),
    P("15m", 21150, 21074, "usb", "100"),
    P("12m", 24930, 24915, "usb", "100"),
    P("10m", 28500, 28074, "usb", "100"),
    P("6m", 50200, 50313, "usb", "100"),
    P("4m (Region 1)", 70200, 70154, "usb", "100"),
]

# --- HF broadcast & utility (SWL) --------------------------------------------
SWL = [
    P("WWV 5 MHz (time)", 5000, 5000, "am", "1000"),
    P("WWV 10 MHz (time)", 10000, 10000, "am", "1000"),
    P("WWV 15 MHz (time)", 15000, 15000, "am", "1000"),
    P("CB 27 MHz", 27200, 27185, "am", "10000"),
    P("49m SW Broadcast", 6050, 6000, "am", "5000"),
    P("41m SW Broadcast", 7300, 7300, "am", "5000"),
    P("31m SW Broadcast", 9650, 9600, "am", "5000"),
    P("25m SW Broadcast", 11850, 11800, "am", "5000"),
    P("22m SW Broadcast", 13700, 13700, "am", "5000"),
    P("19m SW Broadcast", 15400, 15300, "am", "5000"),
    P("16m SW Broadcast", 17700, 17600, "am", "5000"),
    P("13m SW Broadcast", 21650, 21600, "am", "5000"),
]

# --- Aviation ----------------------------------------------------------------
AVIATION = [
    P("Airband 118-120 (AM)", 119000, 118000, "am", "8330"),
    P("Airband Tower/Approach (AM)", 124000, 124000, "am", "8330"),
    P("Airband Guard 121.5", 121500, 121500, "am", "8330"),
    P("UHF Mil Air Guard 243", 243000, 243000, "am", "25000"),
    P("ACARS (131.550)", 131000, 131550, "am", "25000"),
    P("HFDL 8.9 MHz", 8900, 8927, "usb", "100"),
    P("HFDL 11.3 MHz", 11300, 11327, "usb", "100"),
    P("VOLMET 8.8 MHz", 8800, 8828, "usb", "100"),
]

# --- Marine ------------------------------------------------------------------
MARINE = [
    P("Marine VHF (Ch16)", 157000, 156800, "nfm", "25000"),
    P("Marine AIS", 162000, 161975, "nfm", "25000"),
    P("NAVTEX 518 kHz", 500, 518, "usb", "100"),
    P("Marine HF 8 MHz", 8400, 8414, "usb", "100"),
]

# --- Public service & utility ------------------------------------------------
UTILITY = [
    P("GMRS / FRS", 463000, 462563, "nfm", "12500"),
    P("MURS", 152000, 151820, "nfm", "12500"),
    P("PMR446 (EU)", 446100, 446006, "nfm", "6250"),
    P("Railroad (AAR)", 160500, 161100, "nfm", "15000"),
    P("Pagers (POCSAG/FLEX)", 930000, 929000, "nfm", "12500"),
    P("70cm Repeaters", 438800, 439275, "nfm", "12500"),
    # ISM (rtl_433: weather sensors, TPMS, remotes, ...); 433 MHz is in the VHF/UHF group
    P("315 MHz ISM (US)", 315000, 315000, "nfm", "25000"),
    P("915 MHz ISM (US)", 915000, 915000, "nfm", "25000"),
]

# --- Satellite & space (L-band ones need ~1.5-1.7 GHz coverage) --------------
SATELLITE = [
    P("NOAA APT (137)", 137500, 137620, "nfm", "5000"),
    P("ISS (145.8)", 145825, 145825, "nfm", "5000"),
    P("Inmarsat AERO (L-band)", 1545000, 1545000, "usb", "100"),
    P("Iridium (L-band)", 1622000, 1621250, "nfm", "25000"),
]

_ALL = VHF_UHF + HF + SWL + AVIATION + MARINE + UTILITY + SATELLITE


class ProfilePresets(object):
    # ordered: key -> (label, list-of-presets)
    groups = {
        "vhfuhf": ("Common VHF/UHF (any RTL-SDR)", VHF_UHF),
        "hf": ("HF amateur bands (SDRplay / V4)", HF),
        "swl": ("HF broadcast & utility (SWL)", SWL),
        "aviation": ("Aviation", AVIATION),
        "marine": ("Marine", MARINE),
        "utility": ("Public service & utility", UTILITY),
        "satellite": ("Satellite & space", SATELLITE),
        "all": ("All of the above", _ALL),
    }

    @staticmethod
    def getGroupOptions():
        # [(key, label), ...] for building a dropdown
        return [(key, label) for key, (label, _) in ProfilePresets.groups.items()]

    @staticmethod
    def getProfiles(key):
        group = ProfilePresets.groups.get(key)
        return list(group[1]) if group is not None else []
