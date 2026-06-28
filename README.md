OpenWebRX+ (WW2DX fork)
=======================

This is the **WW2DX fork** of [OpenWebRX+](https://github.com/luarvique/openwebrx)
(which is itself an enhanced fork of the original
[OpenWebRX](https://github.com/jketterl/openwebrx) by Jakob Ketterl, DD5JFK).
It tracks upstream OpenWebRX+ and adds decode→Slack reporting, APRS logging,
SDR-profile conveniences, and turnkey deployment tooling for headless Ubuntu
servers. Like its parents, it is licensed under **AGPLv3** (see [Licensing](#licensing)).

## What's new in this fork

### Reporting & logging
- **Slack webhook reporter** — post decoded spots to a Slack channel via an
  incoming webhook. Configure under **Settings → Spotting and reporting → Slack
  webhook settings**:
  - per-mode and per-band filtering (empty = send everything);
  - a **station name** label prepended to every message (defaults to the machine
    hostname) so several receivers can share one channel;
  - **distance, azimuth and Maidenhead grid** added to each spot, computed from
    the receiver location (works for lat/lon spots like APRS and for grid-locator
    spots like FT8/WSPR);
  - server/receiver status reports are never forwarded — only real decodes.
- **APRS decode logging** — decoded APRS packets are appended to
  `/tmp/aprs_decodes.log` as JSON lines, rotated weekly.

### SDR profile management
- **Move profiles between devices** — a "Move to device" control on the profile
  settings page relocates a profile to another SDR device (no more editing
  `settings.json` by hand).
- **One-click common profiles** — an "Add common profiles" button on each device
  bulk-creates a curated set of presets (Common VHF/UHF, HF bands, or All). See
  `owrx/profilepresets.py`.

### Deployment tooling (`deploy/`)
- **One file, one command** to go from a fresh Ubuntu 22.04 server to a fully
  running receiver — installs git, clones this fork, builds the `.deb`, enables
  both apt repos, installs all native dependencies, sets up RTL-SDR, and
  optionally the SDRplay API and software digital voice:
  ```bash
  scp deploy/bootstrap.sh user@server:
  ssh user@server
  sudo bash bootstrap.sh --sdrplay --softmbe --seed-rtlsdr --admin-password 'choose-a-pass'
  ```
- **`--seed-rtlsdr`** pre-creates a NooElec NESDR SMArt v5 device populated with
  the common VHF/UHF profiles, so a single-dongle box comes up with a waterfall
  and zero UI clicks.
- See **[deploy/README.md](deploy/README.md)** for the full build/install guide,
  SDRplay and software-MBE (digital voice) options, and the feature-availability
  check.

---

OpenWebRX+
=========

This is the **improved version** of the OpenWebRX online SDR. The pre-built OpenWebRX+ packages are available from the [package repository](https://luarvique.github.io/ppa/). Pre-built disk images are available from the [Releases page](https://github.com/luarvique/openwebrx/releases). OpenWebRX+ [documentation](https://fms.komkon.org/OWRX/) draft is now available. News, support, and general discussion can be found in the [Telegram channel](https://t.me/openwebrx) and related [chat](https://t.me/openwebrx_chat). Features found in OpenWebRX+ that are not present in the original version:
* AIS, SSTV, FAX, FLEX, POCSAG, HFDL, VDL2, ADSB, ACARS, ISM, RDS, SAM, SITOR-B, RTTY, and CW decoders.
* DTMF, EEA, EIA, CCIR, and several ZVEY SELCALL decoders.
* Background SSTV and FAX decoding with received images browser.
* Built-in chat between receiver users.
* Built-in recorder for received audio.
* Built-in scanner over bookmarks.
* Ability for the admin to see user connections and ban abusive users.
* Adjustable noise filtering based on spectral subtraction.
* Adjustable tuning step.
* Automatically created bookmarks for shortwave broadcasts.
* Automatically created bookmarks for nearby HAM repeaters.
* Waterfall panning and zooming on touchscreen based devices.
* Bandpass control with the scroll wheel.
* Improved tuning in CW mode.
* More reliable SDRPlay devices operation.
* Map shows other public web SDRs from all around the world.
* Map shows shortwave broadcasters from all around the world.
* Map shows aircraft positions received over ADSB, VDL2, HFDL.
* Map shows nearby HAM repeaters.
* Better map information, with distances, APRS paths, weather, etc.
* Support for configurable session timeout, with a policy page.
* HTTPS protocol support (requires certificate).
* Foldable receiver panel with configurable opacity.
* Spectrum display.

Original OpenWebRX
=========

OpenWebRX is a multi-user SDR receiver software with a web interface.

![OpenWebRX](https://www.openwebrx.de/gfx/openwebrx-screenshot.png)

It has the following features:

- [csdr](https://github.com/jketterl/csdr) based demodulators (AM/FM/SSB/CW/BPSK31/BPSK63)
- filter passband can be set from GUI
- it extensively uses HTML5 features like WebSocket, Web Audio API, and Canvas
- it works in Google Chrome, Chromium and Mozilla Firefox
- supports a wide range of [SDR hardware](https://github.com/jketterl/openwebrx/wiki/Supported-Hardware#sdr-devices)
- Multiple SDR devices can be used simultaneously
- [digiham](https://github.com/jketterl/digiham) based demodularors (DMR, YSF, Pocsag, D-Star, NXDN)
- [wsjt-x](https://wsjt.sourceforge.io/) based demodulators (FT8, FT4, WSPR, JT65, JT9, FST4,
  FST4W)
- [direwolf](https://github.com/wb2osz/direwolf) based demodulation of APRS packets
- [JS8Call](http://js8call.com/) support
- [DRM](https://github.com/jketterl/openwebrx/wiki/DRM-demodulator-notes) support
- [FreeDV](https://github.com/jketterl/openwebrx/wiki/FreeDV-demodulator-notes) support
- M17 support based on [m17-cxx-demod](https://github.com/mobilinkd/m17-cxx-demod)

## Setup

For this fork on a fresh Ubuntu 22.04 server, use the deployment tooling in
[deploy/](deploy/README.md) (one-command bootstrap). The upstream setup methods
also apply:

- Raspberry Pi SD card images
- Debian repository
- Docker images
- Manual installation

Please checkout the [setup guide on the wiki](https://github.com/jketterl/openwebrx/wiki/Setup-Guide) for more details
on the respective methods.

## Community

If you have trouble setting up or configuring your receiver, you have some great idea you want to see implemented, or
you just generally want to have some OpenWebRX-related chat, come visit us over on
[our groups.io group](https://groups.io/g/openwebrx).

If you want to hang out, chat, or get in touch directly with the developers, receiver operators or users, feel free to
drop by in [our Discord server](https://discord.gg/gnE9hPz).

## Usage tips

You can zoom the waterfall display by the mouse wheel. You can also drag the waterfall to pan across it.

The filter envelope can be dragged at its ends and moved around to set the passband.

However, if you hold down the shift key, you can drag the center line (BFO) or the whole passband (PBS).

## Licensing

OpenWebRX is available under Affero GPL v3 license
([summary](https://tldrlegal.com/license/gnu-affero-general-public-license-v3-(agpl-3.0))).

OpenWebRX is also available under a commercial license on request. Please contact me at the address
*&lt;randras@sdr.hu&gt;* for licensing options. 
