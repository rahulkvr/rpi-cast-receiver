# RPi speaker in Cast button (YouTube Music, Spotify)

Make your **Raspberry Pi 4 + aux speaker** appear in the **Cast** button of YouTube Music, Spotify, and other Cast apps—**no setup on phones, tablets, or laptops**. Same Wi‑Fi only.

## Goal

- RPi4 + speaker connected via **aux (3.5 mm)**.
- On the **same network**, the speaker shows up in the **Cast** list (YouTube Music, Spotify, Chrome, etc.).
- **No extra apps or setup** on Android, iPhone, laptop, or tablet.

## How it works

This repo uses the **Open Screen** project (Chromium’s open-source Cast implementation) to run a **Cast receiver** on the Pi. The receiver:

- Advertises on the LAN so Cast senders can discover it.
- Accepts TLS and speaks the Cast protocol.
- Decodes and plays streamed media to the Pi’s audio output (your aux speaker).

See [RESEARCH.md](RESEARCH.md) for constraints (Google does not allow building a fully equivalent Chromecast) and compatibility notes (YouTube Music / Spotify may use custom receiver apps).

## Quick start (on the Pi)

### 1. Clone this repo on the Pi

```bash
cd ~
git clone <this-repo-url> rpi-cast-receiver
cd rpi-cast-receiver
```

### 2. Build the Cast receiver (one-time; 15–30+ min on Pi 4)

```bash
chmod +x scripts/*.sh
./scripts/build-openscreen-receiver.sh
```

If the Pi runs out of memory, build on a more powerful Linux machine (same script), then copy `openscreen_build/openscreen/out/Default/cast_receiver` to the Pi and set `CAST_RECEIVER_BIN` when running.

### 3. Set audio output to aux

```bash
./scripts/setup-audio.sh
# Or: sudo raspi-config → System Options → Audio → Headphones
aplay /usr/share/sounds/alsa/Front_Center.wav   # test
```

### 4. Generate credentials and start the receiver

```bash
./scripts/run-receiver.sh
```

First run generates TLS credentials and exits. Run again to start:

```bash
./scripts/run-receiver.sh
```

Use a specific interface if needed:

```bash
./scripts/run-receiver.sh wlan0   # Wi-Fi
./scripts/run-receiver.sh eth0    # Ethernet
```

### 5. Cast from your phone/laptop

- Connect phone/tablet/laptop to the **same Wi‑Fi** as the Pi.
- Open **YouTube Music** or **Spotify** (or Chrome), tap **Cast**.
- Select **"RPi Speaker"** (or the name you set).
- Play; audio should come from the Pi’s speaker.

## Optional: run as a service (start on boot)

```bash
# Edit systemd/cast-receiver.service if your paths or user differ (e.g. interface, friendly name).
sudo cp systemd/cast-receiver.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now cast-receiver
```

Check status: `sudo systemctl status cast-receiver`

## Environment variables

| Variable | Default | Description |
|---------|---------|-------------|
| `CAST_RECEIVER_BUILD_DIR` | `$HOME/openscreen_build` | Where Open Screen is built. |
| `CAST_RECEIVER_BIN` | `$BUILD_DIR/openscreen/out/Default/cast_receiver` | Path to the receiver binary. |
| `CAST_RECEIVER_CREDS_DIR` | `$HOME/.cast_receiver` | Where TLS key/cert are stored. |
| `CAST_RECEIVER_INTERFACE` | `eth0` | Network interface (e.g. `wlan0`). |
| `CAST_RECEIVER_FRIENDLY_NAME` | `RPi Speaker` | Name shown in the Cast list. |

## Troubleshooting

- **Not in Cast list**: Same Wi‑Fi as the Pi? Receiver running? Firewall: allow the port the receiver uses (Open Screen may use 8010; Chromecast uses 8009).
- **No sound**: Run `./scripts/setup-audio.sh` and `raspi-config` → Audio → Headphones; test with `aplay`.
- **Build fails on Pi**: Try building on a PC and copying the `cast_receiver` binary; or increase swap.

## Files

- [RESEARCH.md](RESEARCH.md) – Why this approach, Cast protocol, Open Screen, YT/Spotify caveats.
- `scripts/build-openscreen-receiver.sh` – Build Open Screen `cast_receiver` on the Pi (or another Linux host).
- `scripts/run-receiver.sh` – Generate credentials (first run) and start the receiver.
- `scripts/setup-audio.sh` – Point audio to aux/headphones.
- `systemd/cast-receiver.service` – Example systemd unit for running the receiver on boot.
