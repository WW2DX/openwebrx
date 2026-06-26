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
#   5. enable and start the openwebrx systemd service.
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
#   -h, --help               show this help
#
# Environment overrides:
#   OWRX_ADMIN_PASSWORD   if set, auto-creates the web admin user 'admin'
#   SDRPLAY_VERSION       SDRplay API version (default 3.15.2)
#   SDRPLAY_URL           full override for the SDRplay .run download URL
#   SDRPLAY_SHA256        if set, the .run download is checksum-verified
#
set -euo pipefail

# ---- defaults ---------------------------------------------------------------
DEB_FILE=""
DEB_URL=""
WITH_SDRPLAY=0
ACCEPT_SDRPLAY_EULA=0
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
        -h|--help)             sed -n '2,40p' "$0"; exit 0 ;;
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

# ---- 2. OpenWebRX+ apt repo -------------------------------------------------
log "Enabling the OpenWebRX+ apt repository..."
curl -fsSL https://luarvique.github.io/ppa/openwebrx-plus.gpg \
    | gpg --yes --dearmor -o /etc/apt/trusted.gpg.d/openwebrx-plus.gpg
tee /etc/apt/sources.list.d/openwebrx-plus.list >/dev/null \
    <<<"deb [signed-by=/etc/apt/trusted.gpg.d/openwebrx-plus.gpg] https://luarvique.github.io/ppa/ubuntu ./"
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
