# Deploying the WW2DX OpenWebRX+ fork

This directory packages the fork as a Debian package and installs it on a fresh
**Ubuntu 22.04** headless server (amd64 — e.g. an Intel Mac mini) in one shot.

## How it works

The `openwebrx` package is `Architecture: all` (pure Python). It does **not**
contain SDR drivers — it *depends* on them. All the native pieces (`csdr`,
`owrx-connector`, `direwolf`, `wsjtx`, sonde decoders, etc.) come from the
official **OpenWebRX+ apt repository**, which `apt` pulls in automatically.

| Device | Setup |
|---|---|
| **RTL-SDR** | Automatic — `owrx-connector` (a hard dependency) provides the driver. The installer also blacklists the DVB kernel module. |
| **SDRplay (RSP)** | Needs `--sdrplay`. The proprietary SDRplay API **cannot be redistributed**, so the installer downloads it from SDRplay's official site at install time (pinned to v3.15.2) and installs the `soapysdr-module-sdrplay3` bridge from the repo. |

## Digital voice (D-Star / DMR / YSF / NXDN)

These modes use the AMBE voice codec, so they need a CodecServer with AMBE
support. Two options:

- **Software (mbelib)** — `--softmbe`. No extra hardware. Runs the OpenWebRX+
  project's official `install-softmbe.sh`, which builds `mbelib` and
  `codecserver-softmbe` from source and wires them into CodecServer.
  > ⚠️ **Patent risk:** mbelib is an unlicensed codec implementation of
  > questionable origin; decoding AMBE/IMBE in software this way may be
  > interpreted as a patent violation. `--softmbe` requires you to accept this
  > (interactively, or with `--accept-softmbe-patent-risk`).
- **Hardware dongle** — `--ambe-device /dev/ttyUSB0` (optionally `--ambe-baud`).
  Installs `codecserver` + `codecserver-driver-ambe3k` and configures CodecServer
  to use an AMBE dongle (ThumbDV, DVstick30, …). No patent concern.

Pick one. Either way, leave OpenWebRX's **Settings → Decoding → Digital voice →
Codecserver address** empty (it talks to the local CodecServer by default).

## 1. Build the package

On any Ubuntu/Debian box (or one of the servers):

```bash
deploy/build-deb.sh
# -> produces ../openwebrx_<version>_all.deb
```

Publish it where your servers can reach it. **Recommended:** attach the `.deb` to
a [GitHub Release](https://github.com/WW2DX/openwebrx/releases) rather than
committing the binary to the repo.

> Note: do **not** commit the SDRplay API installer to the repo — it is
> proprietary and license-restricted. The installer fetches it from SDRplay
> directly, so there is nothing to host.

## 2. Install on a fresh server

Copy `deploy/install.sh` to the box (or `curl` it from your release), then:

```bash
# RTL-SDR only, installing your built .deb:
sudo ./install.sh --deb ./openwebrx_*.deb

# ...pulling the .deb from a GitHub release instead:
sudo ./install.sh --deb-url https://github.com/WW2DX/openwebrx/releases/download/vX/openwebrx_X_all.deb

# ...and add SDRplay support (downloads the API from sdrplay.com, EULA required):
sudo ./install.sh --deb ./openwebrx_*.deb --sdrplay --accept-sdrplay-eula

# ...with software digital-voice (D-Star/DMR/YSF/NXDN via mbelib - patent risk):
sudo ./install.sh --deb ./openwebrx_*.deb --softmbe --accept-softmbe-patent-risk

# auto-create the web admin user in the same run:
sudo OWRX_ADMIN_PASSWORD='choose-a-password' ./install.sh --deb ./openwebrx_*.deb
```

When it finishes, OpenWebRX is live at `http://<server-ip>:8073/`.

### Options
- `--deb FILE` / `--deb-url URL` — install your fork's package (omit both to install the stock repo package).
- `--sdrplay` — also install the SDRplay RSP API + Soapy module.
- `--accept-sdrplay-eula` — accept SDRplay's license non-interactively (otherwise you're prompted).
- `--softmbe` — software digital voice via mbelib (patent risk; see above).
- `--accept-softmbe-patent-risk` — accept the mbelib patent risk non-interactively.
- `--ambe-device DEV` / `--ambe-baud BAUD` — hardware AMBE dongle instead of `--softmbe`.
- `OWRX_ADMIN_PASSWORD=...` — auto-create the `admin` web user.
- `SDRPLAY_VERSION` / `SDRPLAY_URL` / `SDRPLAY_SHA256` — override the SDRplay download (default 3.15.2). On the first run the script prints the downloaded file's SHA-256; set `SDRPLAY_SHA256` to that value on later runs to pin integrity.

## 3. Post-install
- Check which modes/decoders are available (digital voice highlighted):
  `sudo deploy/check-features.sh` — `install.sh` runs this automatically at the end.
- Create the web admin (if you didn't preseed it): `sudo openwebrx admin adduser admin`
- Set the receiver position so Slack spot **distance/azimuth** are correct:
  Settings → General settings → Receiver location.
- Configure the Slack webhook: Settings → Spotting and reporting → Slack webhook settings.

## Notes & caveats
- **Architectures:** tuned for amd64 (Intel). The RTL-SDR path is arch-agnostic; the SDRplay file placement assumes an `x86_64` payload.
- **SDRplay licensing:** the API is third-party proprietary software. This tooling never redistributes it — it only automates the download you are licensed to perform, and surfaces the EULA.
- **Dependencies:** everything else resolves from the OpenWebRX+ repo. If a specific decoder is ever missing, check the repo at <https://luarvique.github.io/ppa/>.
