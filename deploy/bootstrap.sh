#!/usr/bin/env bash
#
# One-file bootstrap: fresh Ubuntu 22.04 server -> fully installed & running
# OpenWebRX+ (WW2DX fork).
#
# Copy just THIS file to a fresh server and run it. It installs git, clones the
# fork, builds the .deb, and runs the full installer (repos + dependencies +
# RTL-SDR + optional SDRplay + optional software digital voice + systemd
# service + web admin user).
#
#   scp deploy/bootstrap.sh user@server:
#   ssh user@server
#   sudo bash bootstrap.sh --sdrplay --softmbe --admin-password 'choose-a-pass'
#
# Options:
#   --sdrplay                install the SDRplay RSP API + Soapy module
#   --softmbe                software digital voice (D-Star/DMR/YSF/NXDN via mbelib)
#   --ambe-device DEV        hardware AMBE dongle instead of --softmbe (e.g. /dev/ttyUSB0)
#   --ambe-baud BAUD         AMBE dongle baud rate (default 921600)
#   --admin-password PASS    create the web admin user 'admin' with this password
#   --repo URL               git repo to build from (default the WW2DX fork)
#   --branch NAME            git branch to build (default master)
#   --src-dir DIR            where to clone the source (default /usr/local/src/openwebrx)
#   -h, --help               show this help
#
# Licenses: --sdrplay accepts SDRplay's EULA and --softmbe accepts the mbelib
# patent risk on your behalf (this is the unattended bootstrap). Omit them and
# run deploy/install.sh interactively if you'd rather be prompted.
#
set -euo pipefail

REPO="${REPO:-https://github.com/WW2DX/openwebrx.git}"
BRANCH="${BRANCH:-master}"
SRC_DIR="${SRC_DIR:-/usr/local/src/openwebrx}"
ADMIN_PASSWORD=""
PASS_ARGS=()

log()  { echo -e "\033[1;36m####\033[0m $*"; }
die()  { echo -e "\033[1;31merror:\033[0m $*" >&2; exit 1; }

while [ $# -gt 0 ]; do
    case "$1" in
        --sdrplay)        PASS_ARGS+=("--sdrplay" "--accept-sdrplay-eula"); shift ;;
        --softmbe)        PASS_ARGS+=("--softmbe" "--accept-softmbe-patent-risk"); shift ;;
        --ambe-device)    PASS_ARGS+=("--ambe-device" "${2:?--ambe-device needs a value}"); shift 2 ;;
        --ambe-baud)      PASS_ARGS+=("--ambe-baud" "${2:?--ambe-baud needs a value}"); shift 2 ;;
        --admin-password) ADMIN_PASSWORD="${2:?--admin-password needs a value}"; shift 2 ;;
        --repo)           REPO="${2:?--repo needs a value}"; shift 2 ;;
        --branch)         BRANCH="${2:?--branch needs a value}"; shift 2 ;;
        --src-dir)        SRC_DIR="${2:?--src-dir needs a value}"; shift 2 ;;
        -h|--help)        sed -n '2,40p' "$0"; exit 0 ;;
        *)                die "unknown option: $1 (try --help)" ;;
    esac
done

[ "$(id -u)" -eq 0 ] || die "please run as root (sudo bash $0 ...)"

export DEBIAN_FRONTEND=noninteractive

log "Installing git and prerequisites..."
apt-get update
apt-get install -y git ca-certificates curl

log "Fetching the source (${REPO} @ ${BRANCH})..."
if [ -d "${SRC_DIR}/.git" ]; then
    git -C "${SRC_DIR}" remote set-url origin "${REPO}"
    git -C "${SRC_DIR}" fetch --depth 1 origin "${BRANCH}"
    git -C "${SRC_DIR}" checkout -B "${BRANCH}" "origin/${BRANCH}"
    git -C "${SRC_DIR}" reset --hard "origin/${BRANCH}"
else
    rm -rf "${SRC_DIR}"
    git clone --depth 1 --branch "${BRANCH}" "${REPO}" "${SRC_DIR}"
fi

cd "${SRC_DIR}"

log "Building the package..."
bash deploy/build-deb.sh

deb="$(ls -1t "${SRC_DIR}/.."/openwebrx_*_all.deb 2>/dev/null | head -1 || true)"
[ -n "${deb}" ] || die "build did not produce a .deb"
log "Built ${deb}"

log "Running the installer..."
if [ -n "${ADMIN_PASSWORD}" ]; then
    OWRX_ADMIN_PASSWORD="${ADMIN_PASSWORD}" bash deploy/install.sh --deb "${deb}" "${PASS_ARGS[@]}"
else
    bash deploy/install.sh --deb "${deb}" "${PASS_ARGS[@]}"
fi

log "Bootstrap complete."
echo
echo "Next: open the web UI, then under Settings -> SDR devices add your dongle"
echo "and click 'Add common profiles' to populate it. Set your receiver location"
echo "and Slack webhook under Settings as well."
