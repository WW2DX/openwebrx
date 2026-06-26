#!/usr/bin/env bash
#
# Build the OpenWebRX+ (WW2DX fork) Debian package.
#
# The package is Architecture: all (pure Python), so this builds in seconds and
# the resulting .deb can be installed on any amd64/arm64 box that has the
# OpenWebRX+ apt repo enabled (the repo provides csdr, owrx-connector, direwolf,
# wsjtx and all the other native dependencies).
#
# Run this on any Ubuntu/Debian machine (it can even be one of the target
# servers). The artifact lands in the parent directory as:
#     ../openwebrx_<version>_all.deb
#
# Usage:
#   deploy/build-deb.sh            # build openwebrx_<version>_all.deb
#
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${here}/.." && pwd)"
cd "${repo_root}"

if [ ! -f debian/control ]; then
    echo "error: debian/control not found - run this from the openwebrx repo." >&2
    exit 1
fi

echo "==> Installing build dependencies..."
sudo apt-get update
sudo apt-get install -y --no-install-recommends \
    build-essential \
    fakeroot \
    dpkg-dev \
    debhelper \
    dh-python \
    python3-all \
    python3-setuptools

echo "==> Building package..."
# Skip the unit test suite during the build: it imports pycsdr (from the
# runtime dependency python3-csdr), which is not a build dependency and is not
# present on a plain build host. nocheck is the standard Debian way to skip
# dh_auto_test; it does not affect the resulting package.
export DEB_BUILD_OPTIONS="nocheck${DEB_BUILD_OPTIONS:+ ${DEB_BUILD_OPTIONS}}"
# -us -uc: don't sign; -b: binary-only (no source tarball needed)
dpkg-buildpackage -us -uc -b

artifact="$(ls -1t "${repo_root}/.."/openwebrx_*_all.deb 2>/dev/null | head -1 || true)"
if [ -z "${artifact}" ]; then
    echo "error: build finished but no .deb was found in ${repo_root}/.." >&2
    exit 1
fi

echo
echo "==> Built: ${artifact}"
echo "    Install on a server with:  sudo apt install ./$(basename "${artifact}")"
echo "    (or use deploy/install.sh for a full one-shot setup)"
