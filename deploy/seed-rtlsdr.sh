#!/usr/bin/env bash
#
# Seed a default NooElec NESDR SMArt v5 (RTL-SDR) device, pre-populated with the
# common VHF/UHF profiles, so a single-dongle box comes up with a waterfall and
# zero UI clicks.
#
# Idempotent and non-destructive: does nothing if any SDR device is already
# configured in settings.json (so it only ever touches a truly fresh install).
#
#   sudo deploy/seed-rtlsdr.sh
#
# Env overrides:
#   DEVICE_NAME    device name      (default "NESDR SMArt v5")
#   PRESET_GROUP   preset group     (default "vhfuhf"; see owrx/profilepresets.py)
#
# Note: the stock NESDR reliably covers VHF/UHF (~25 MHz-1.75 GHz), so the seed
# uses the VHF/UHF presets. For HF, use an SDRplay / RTL-SDR V4 (the NESDR needs
# a degraded, frequency-limited direct-sampling mode for HF).
#
set -euo pipefail

[ "$(id -u)" -eq 0 ] || { echo "error: run as root (sudo $0)" >&2; exit 1; }

DEVICE_NAME="${DEVICE_NAME:-NESDR SMArt v5}"
PRESET_GROUP="${PRESET_GROUP:-vhfuhf}"

# run python as the openwebrx service user so settings.json keeps correct
# ownership; fall back to the current (root) user if that account is absent.
run_as_owrx() {
    if id openwebrx >/dev/null 2>&1; then
        runuser -u openwebrx -- "$@"
    else
        "$@"
    fi
}

# stop the service so it reloads the seeded config and doesn't overwrite the file
systemctl stop openwebrx 2>/dev/null || true

tmp_py="$(mktemp /tmp/owrx-seed.XXXXXX.py)"
chmod 0644 "${tmp_py}"   # readable by the openwebrx user
cat > "${tmp_py}" <<'PY'
import sys, os, json
from uuid import uuid4
# import owrx BEFORE changing directory: a source-tree install is importable via
# the app dir (cwd), while a packaged install lives in site-packages either way.
from owrx.config.core import CoreConfig
from owrx.config import Config
from owrx.property import PropertyLayer
from owrx.profilepresets import ProfilePresets

os.chdir("/tmp")  # avoid ClassicConfig picking up a ./config_webrx.py from cwd
CoreConfig.load()

group, name = sys.argv[1], sys.argv[2]

# only seed a fresh box: skip if SDR devices were already written by the user/UI
settings = os.path.join(CoreConfig().get_data_directory(), "settings.json")
try:
    with open(settings) as f:
        raw = json.load(f)
except Exception:
    raw = {}
if raw.get("sdrs"):
    print("SKIP: an SDR device is already configured; not seeding.")
    raise SystemExit(0)

profiles = PropertyLayer()
for preset in ProfilePresets.getProfiles(group):
    profiles[str(uuid4())] = PropertyLayer(**preset)

if len(profiles) == 0:
    print("SKIP: preset group '%s' is empty." % group)
    raise SystemExit(0)

device = PropertyLayer(
    name=name,
    type="rtl_sdr",
    rf_gain="auto",
    direct_sampling=0,
    profiles=profiles,
)
sdrs = PropertyLayer()
sdrs[str(uuid4())] = device

pm = Config.get()
pm["sdrs"] = sdrs
pm.store()
print("Seeded '%s' (rtl_sdr) with %d profiles." % (name, len(profiles)))
PY

run_as_owrx python3 "${tmp_py}" "${PRESET_GROUP}" "${DEVICE_NAME}"
rm -f "${tmp_py}"

systemctl start openwebrx 2>/dev/null || true
