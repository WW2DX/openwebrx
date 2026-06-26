#!/usr/bin/env bash
#
# One-shot installer for the OpenWebRX+ (WW2DX fork) on a fresh headless
# Ubuntu 22.04 server (amd64 - e.g. an Intel Mac mini).
#
# It will:
#   1. enable the OpenWebRX+ apt repository (provides csdr, owrx-connector,
#      direwolf, wsjtx and all other native dependencies),
#   2. install the fork's openwebrx .deb (your code), with apt resolving deps,
#   3. set up RTL-SDR (blacklist the DVB kernel driver),
#   4. optionally install the SDRplay RSP API + Soapy module (--sdrplay),
#   5. optionally set up CodecServer + AMBE for digital voice (--ambe-device),
#   6. enable and start the openwebrx systemd service, then print a feature report.
#
# RTL-SDR works with no extra flags. SDRplay needs --sdrplay because its API is
# proprietary: this script DOWNLOADS it from SDRplay's official site at install
# time (it is never redistributed here), and you must accept SDRplay's EULA.
#
# Usage (run as root):
#   sudo ./install.sh --deb ./openwebrx_1.2.117_all.deb
#   sudo ./install.sh --deb-url https://github.com/WW2DX/openwebrx/releases/download/vX/openwebrx_X_all.deb
#   sudo ./install.sh --deb ./openwebrx_*.deb --sdrplay --accept-sdrplay-eula
#
# Options:
#   --deb FILE               install this local .deb (your fork's package)
#   --deb-url URL            download and install the .deb from this URL
#   (omit both to install the stock 'openwebrx' package from the repo instead)
#   --sdrplay                also install the SDRplay RSP API + Soapy module
#   --accept-sdrplay-eula    accept SDRplay's license non-interactively
#   --ambe-device DEV        configure CodecServer for a hardware AMBE dongle on
#                            serial port DEV (e.g. /dev/ttyUSB0) so D-Star/DMR/
#                            YSF/NXDN decode. Requires an AMBE dongle (ThumbDV,
#                            DVstick30, etc.); AMBE cannot be done in software here.
#   --ambe-baud BAUD         AMBE dongle baud rate (default 921600)
#   --softmbe                set up SOFTWARE AMBE/IMBE via mbelib instead of a
#                            dongle, so D-Star/DMR/YSF/NXDN decode with no extra
#                            hardware. PATENT RISK: mbelib is an unlicensed codec
#                            of questionable origin; using it may be a patent
#                            violation. Runs the OpenWebRX+ project's official
#                            install-softmbe.sh.
#   --accept-softmbe-patent-risk  accept the mbelib patent risk non-interactively
#   -h, --help               show this help
#
# Environment overrides:
#   OWRX_ADMIN_PASSWORD   if set, auto-creates the web admin user 'admin'
#   SDRPLAY_VERSION       SDRplay API version (default 3.15.2)
#   SDRPLAY_URL           full override for the SDRplay .run download URL
#   SDRPLAY_SHA256        if set, the .run download is checksum-verified
#
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---- defaults ---------------------------------------------------------------
DEB_FILE=""
DEB_URL=""
WITH_SDRPLAY=0
ACCEPT_SDRPLAY_EULA=0
AMBE_DEVICE=""
AMBE_BAUD="921600"
WITH_SOFTMBE=0
ACCEPT_SOFTMBE=0
SOFTMBE_URL="${SOFTMBE_URL:-https://fms.komkon.org/OWRX/install-softmbe.sh}"
SDRPLAY_VERSION="${SDRPLAY_VERSION:-3.15.2}"
SDRPLAY_URL="${SDRPLAY_URL:-https://www.sdrplay.com/software/SDRplay_RSP_API-Linux-${SDRPLAY_VERSION}.run}"
SDRPLAY_SHA256="${SDRPLAY_SHA256:-}"
OWRX_ADMIN_PASSWORD="${OWRX_ADMIN_PASSWORD:-}"

log()  { echo -e "\033[1;32m==>\033[0m $*"; }
warn() { echo -e "\033[1;33mwarning:\033[0m $*" >&2; }
die()  { echo -e "\033[1;31merror:\033[0m $*" >&2; exit 1; }

# ---- args -------------------------------------------------------------------
while [ $# -gt 0 ]; do
    case "$1" in
        --deb)                 DEB_FILE="${2:?--deb needs a path}"; shift 2 ;;
        --deb-url)             DEB_URL="${2:?--deb-url needs a URL}"; shift 2 ;;
        --sdrplay)             WITH_SDRPLAY=1; shift ;;
        --accept-sdrplay-eula) ACCEPT_SDRPLAY_EULA=1; shift ;;
        --ambe-device)         AMBE_DEVICE="${2:?--ambe-device needs a serial port}"; shift 2 ;;
        --ambe-baud)           AMBE_BAUD="${2:?--ambe-baud needs a value}"; shift 2 ;;
        --softmbe)             WITH_SOFTMBE=1; shift ;;
        --accept-softmbe-patent-risk) ACCEPT_SOFTMBE=1; shift ;;
        -h|--help)             sed -n '2,56p' "$0"; exit 0 ;;
        *) die "unknown option: $1 (try --help)" ;;
    esac
done

[ "$(id -u)" -eq 0 ] || die "please run as root (sudo $0 ...)"

arch="$(dpkg --print-architecture 2>/dev/null || echo unknown)"
[ "${arch}" = "amd64" ] || warn "this script is tuned for amd64; detected '${arch}'. RTL-SDR will still work; the SDRplay section assumes x86_64."

# ---- 1. base tools ----------------------------------------------------------
log "Installing base tools..."
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends curl ca-certificates gnupg

# ---- 2. apt repositories ----------------------------------------------------
# OpenWebRX+ needs BOTH repos:
#   - luarvique PPA: openwebrx(+), owrx-connector, python3-csdr, soapy modules
#   - original repo.openwebrx.de: codecserver, digiham, libcodecserver-dev, ...
log "Enabling the OpenWebRX+ apt repository (luarvique PPA)..."
curl -fsSL https://luarvique.github.io/ppa/openwebrx-plus.gpg \
    | gpg --yes --dearmor -o /etc/apt/trusted.gpg.d/openwebrx-plus.gpg
tee /etc/apt/sources.list.d/openwebrx-plus.list >/dev/null \
    <<<"deb [signed-by=/etc/apt/trusted.gpg.d/openwebrx-plus.gpg] https://luarvique.github.io/ppa/ubuntu ./"

log "Enabling the original OpenWebRX apt repository (codecserver, digiham, ...)..."
codename="$(. /etc/os-release 2>/dev/null && echo "${VERSION_CODENAME:-jammy}")"
curl -fsSL https://repo.openwebrx.de/openwebrx.gpg -o /usr/share/keyrings/openwebrx.gpg
tee /etc/apt/sources.list.d/openwebrx.list >/dev/null \
    <<<"deb [signed-by=/usr/share/keyrings/openwebrx.gpg] https://repo.openwebrx.de/ubuntu/ ${codename} main"

apt-get update

# ---- optional: preseed the web admin password -------------------------------
if [ -n "${OWRX_ADMIN_PASSWORD}" ]; then
    log "Preseeding the web admin ('admin') password..."
    echo "openwebrx openwebrx/admin_user_password password ${OWRX_ADMIN_PASSWORD}" | debconf-set-selections
fi

# ---- 3. install openwebrx (your fork's .deb, or the stock package) ----------
if [ -n "${DEB_URL}" ]; then
    log "Downloading the openwebrx package..."
    curl -fSL "${DEB_URL}" -o /tmp/openwebrx.deb
    DEB_FILE=/tmp/openwebrx.deb
fi

if [ -n "${DEB_FILE}" ]; then
    # expand a glob like openwebrx_*.deb to a concrete path
    DEB_FILE="$(ls -1 ${DEB_FILE} 2>/dev/null | head -1 || true)"
    [ -n "${DEB_FILE}" ] && [ -f "${DEB_FILE}" ] || die "deb file not found"
    log "Installing ${DEB_FILE} (apt resolves dependencies from the repo)..."
    apt-get install -y "$(readlink -f "${DEB_FILE}")"
else
    log "Installing the stock 'openwebrx' package from the repo..."
    apt-get install -y openwebrx
fi

# ---- 4. RTL-SDR -------------------------------------------------------------
log "Configuring RTL-SDR (blacklisting the DVB kernel driver)..."
cat >/etc/modprobe.d/blacklist-rtlsdr.conf <<'EOF'
# Prevent the DVB-T driver from grabbing RTL-SDR dongles so SDR tools can use them.
blacklist dvb_usb_rtl28xxu
EOF
# unload it now if present (a reboot also clears it)
modprobe -r dvb_usb_rtl28xxu 2>/dev/null || true

# ---- 5. SDRplay (optional) --------------------------------------------------
if [ "${WITH_SDRPLAY}" -eq 1 ]; then
    log "Installing SDRplay RSP API ${SDRPLAY_VERSION}..."
    echo
    echo "  The SDRplay API is proprietary, third-party software."
    echo "  It is downloaded directly from SDRplay's official site:"
    echo "      ${SDRPLAY_URL}"
    echo "  By continuing you accept SDRplay's license/EULA (bundled in the installer"
    echo "  and at https://www.sdrplay.com/ )."
    echo
    if [ "${ACCEPT_SDRPLAY_EULA}" -ne 1 ]; then
        read -r -p "  Accept the SDRplay license and continue? [y/N] " reply
        case "${reply}" in [yY]|[yY][eE][sS]) ;; *) die "SDRplay install declined." ;; esac
    fi

    work="$(mktemp -d)"
    trap 'rm -rf "${work}"' EXIT

    log "Downloading the SDRplay installer..."
    curl -fSL "${SDRPLAY_URL}" -o "${work}/sdrplay.run"

    if [ -n "${SDRPLAY_SHA256}" ]; then
        echo "${SDRPLAY_SHA256}  ${work}/sdrplay.run" | sha256sum -c - \
            || die "SDRplay installer checksum mismatch"
    else
        warn "no SDRPLAY_SHA256 set; skipping integrity check. Computed checksum (pin this for future runs):"
        sha256sum "${work}/sdrplay.run" | awk '{print "         "$1}'
    fi

    # Extract the self-extracting (makeself) installer WITHOUT running its
    # interactive EULA prompt - this is the standard headless approach.
    chmod +x "${work}/sdrplay.run"
    "${work}/sdrplay.run" --noexec --target "${work}/extracted" >/dev/null

    log "Placing SDRplay library, service and rules..."
    lib="$(find "${work}/extracted" -type f -name 'libsdrplay_api.so.*' \
            \( -path '*x86_64*' -o -path '*amd64*' \) | head -1)"
    [ -n "${lib}" ] || die "could not find an x86_64 libsdrplay_api.so in the SDRplay payload"
    libname="$(basename "${lib}")"            # e.g. libsdrplay_api.so.3.15
    ver="${libname#libsdrplay_api.so.}"        # e.g. 3.15
    maj="${ver%%.*}"                            # e.g. 3
    install -D -m0755 "${lib}" "/usr/local/lib/${libname}"
    ln -sf "/usr/local/lib/${libname}" "/usr/local/lib/libsdrplay_api.so.${maj}"
    ln -sf "/usr/local/lib/libsdrplay_api.so.${maj}" "/usr/local/lib/libsdrplay_api.so"

    # headers (optional, harmless if absent)
    find "${work}/extracted" -name 'sdrplay_api*.h' -exec install -D -m0644 {} /usr/local/include/ \; 2>/dev/null || true

    # the API daemon
    svc="$(find "${work}/extracted" -type f -name 'sdrplay_apiService' \
            \( -path '*x86_64*' -o -path '*amd64*' \) | head -1)"
    [ -n "${svc}" ] || die "could not find an x86_64 sdrplay_apiService in the SDRplay payload"
    install -D -m0755 "${svc}" /usr/local/bin/sdrplay_apiService

    # udev rules (whatever the payload ships)
    find "${work}/extracted" -name '*.rules' -exec install -D -m0644 {} /etc/udev/rules.d/ \; 2>/dev/null || true
    udevadm control --reload-rules 2>/dev/null || true
    udevadm trigger 2>/dev/null || true

    ldconfig

    # run the API daemon under systemd
    cat >/etc/systemd/system/sdrplay.service <<'EOF'
[Unit]
Description=SDRplay RSP API Service
After=network.target

[Service]
ExecStart=/usr/local/bin/sdrplay_apiService
Restart=always

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable --now sdrplay.service

    # the Soapy bridge that OpenWebRX uses to talk to the API (from the repo)
    log "Installing soapysdr-module-sdrplay3..."
    apt-get install -y soapysdr-module-sdrplay3 || \
        warn "soapysdr-module-sdrplay3 not available from the configured repos; install it manually."
fi

# ---- 5b. CodecServer + AMBE for digital voice (optional) --------------------
if [ -n "${AMBE_DEVICE}" ]; then
    log "Setting up CodecServer + AMBE (digital voice) for dongle on ${AMBE_DEVICE}..."
    # codecserver + the ambe3k hardware driver + the digiham decoder bindings
    apt-get install -y codecserver codecserver-driver-ambe3k python3-digiham

    cfg=/etc/codecserver/codecserver.conf
    [ -f "${cfg}" ] || cfg=/usr/local/etc/codecserver/codecserver.conf
    if [ ! -f "${cfg}" ]; then
        warn "CodecServer config not found; creating ${cfg}"
        mkdir -p "$(dirname "${cfg}")"
        printf '%s\n' '[server:unixdomainsockets]' > "${cfg}"
    fi

    if grep -q "driver=ambe3k" "${cfg}"; then
        log "An ambe3k device is already configured in ${cfg}; leaving it as-is."
    else
        log "Adding ambe3k device (${AMBE_DEVICE} @ ${AMBE_BAUD}) to ${cfg}..."
        cat >>"${cfg}" <<EOF

# Added by openwebrx deploy/install.sh - hardware AMBE dongle
[device:dv3k]
driver=ambe3k
tty=${AMBE_DEVICE}
baudrate=${AMBE_BAUD}
EOF
    fi

    # serial access for codecserver, and socket access for openwebrx
    usermod -aG dialout codecserver 2>/dev/null || true
    if getent group codecserver >/dev/null 2>&1; then
        usermod -aG codecserver openwebrx 2>/dev/null || true
    fi

    systemctl enable --now codecserver 2>/dev/null \
        || warn "could not enable codecserver via systemd; start it manually."
    systemctl restart codecserver 2>/dev/null || true
fi

# ---- 5c. Software MBE (mbelib) for digital voice (optional) -----------------
if [ "${WITH_SOFTMBE}" -eq 1 ]; then
    log "Setting up SOFTWARE MBE (mbelib) for digital voice..."
    echo
    echo "  ============================ PATENT NOTICE ============================"
    echo "  Software MBE uses an unlicensed mbelib implementation of questionable"
    echo "  origin. Decoding AMBE/IMBE digital voice in software this way MAY be"
    echo "  interpreted as a patent violation in your jurisdiction. You are"
    echo "  installing it at your own risk and responsibility."
    echo
    echo "  This runs the OpenWebRX+ project's official installer (builds mbelib"
    echo "  and codecserver-softmbe from source):"
    echo "      ${SOFTMBE_URL}"
    echo "  ======================================================================"
    echo
    if [ "${ACCEPT_SOFTMBE}" -ne 1 ]; then
        read -r -p "  Accept the patent risk and install software MBE? [y/N] " reply
        case "${reply}" in [yY]|[yY][eE][sS]) ;; *) die "Software MBE install declined." ;; esac
    fi

    # codecserver runtime + dev headers + digiham bindings are prerequisites
    apt-get install -y codecserver libcodecserver-dev python3-digiham

    softmbe_dir="$(mktemp -d)"
    log "Downloading the official install-softmbe.sh..."
    curl -fSL "${SOFTMBE_URL}" -o "${softmbe_dir}/install-softmbe.sh"
    chmod +x "${softmbe_dir}/install-softmbe.sh"
    log "Running install-softmbe.sh (this compiles mbelib + codecserver-softmbe)..."
    ( cd "${softmbe_dir}" && bash ./install-softmbe.sh )
    rm -rf "${softmbe_dir}"

    # the script adds a [device:softmbe] section but does not restart the service
    systemctl restart codecserver 2>/dev/null || true
fi

# ---- 6. enable the service --------------------------------------------------
log "Enabling and starting OpenWebRX..."
systemctl enable --now openwebrx

# ---- done -------------------------------------------------------------------
ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
echo
log "Done. OpenWebRX is running at:  http://${ip:-<server-ip>}:8073/"
if [ -n "${OWRX_ADMIN_PASSWORD}" ]; then
    echo "    Web admin user 'admin' was created with the password you supplied."
else
    echo "    Create a web admin user with:  sudo openwebrx admin adduser admin"
fi
echo "    Set the receiver location (for Slack distance/azimuth) under:"
echo "    Settings -> General settings -> Receiver location"

# ---- feature report ---------------------------------------------------------
if [ -x "${here}/check-features.sh" ]; then
    echo
    log "Feature availability on this box:"
    # give codecserver/services a moment to come up before probing
    sleep 2
    "${here}/check-features.sh" || warn "feature check could not run (is openwebrx installed?)"
    if [ -n "${AMBE_DEVICE}" ] || [ "${WITH_SOFTMBE}" -eq 1 ]; then
        echo "    If the AMBE row shows '--', check:  systemctl status codecserver"
        [ -n "${AMBE_DEVICE}" ] && echo "    (and verify the dongle is present at ${AMBE_DEVICE})"
    fi
fi
