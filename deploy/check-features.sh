#!/usr/bin/env bash
#
# Report which OpenWebRX decoder/mode features are available on this machine,
# with a focus on the digital-voice (AMBE) modes: D-Star, DMR, YSF, NXDN.
#
# These modes require `digital_voice_digiham`, which needs both the digiham
# bindings AND a reachable CodecServer that has an AMBE codec (i.e. a hardware
# AMBE dongle configured via deploy/install.sh --ambe-device).
#
# Run on a server that already has openwebrx installed:
#   deploy/check-features.sh           (run as root or with sudo for an accurate
#                                       result - it connects to CodecServer as
#                                       the openwebrx service user)
#
set -euo pipefail

read -r -d '' PYCODE <<'PY' || true
from owrx.config.core import CoreConfig
CoreConfig.load()
from owrx.feature import FeatureDetector

fd = FeatureDetector()
report = fd.feature_report()

groups = [
    ("Digital voice - AMBE (D-Star / DMR / YSF / NXDN)", ["digital_voice_digiham"]),
    ("Digital voice - other", ["digital_voice_freedv", "digital_voice_m17", "digital_voice_rade"]),
    ("Common decoders", ["packet", "wsjt-x", "js8call", "sonde", "acars", "vdl2", "hfdl"]),
]

def mark(ok):
    return "[ OK ]" if ok else "[ -- ]"

for title, feats in groups:
    print(title + ":")
    for f in feats:
        if f not in report:
            continue
        info = report[f]
        print("  {} {}".format(mark(info["available"]), f))
        if not info["available"]:
            missing = [r for r, d in info["requirements"].items() if not d["available"]]
            if missing:
                print("           missing: " + ", ".join(missing))
    print()
PY

# Connect to CodecServer as the same user the service runs as, when possible.
if [ "$(id -u)" -eq 0 ] && id openwebrx >/dev/null 2>&1; then
    printf '%s' "${PYCODE}" | sudo -u openwebrx python3 -
else
    printf '%s' "${PYCODE}" | python3 -
fi
