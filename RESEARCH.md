# Research: RPi speaker in Cast button (YouTube Music, Spotify)

## Goal

- RPi4 + speaker connected via **aux (3.5 mm)**.
- When on the **same network**, the speaker appears in the **cast button** of YouTube Music, Spotify (and ideally other Cast apps).
- **No setup on clients**: Android, iPhone, laptop, tablets—just open the app, tap Cast, and see the device.

## Constraint from Google

Google’s own docs state: *"It is not possible to build a binary functionally equivalent to a Chromecast"* ([Chromium Cast build instructions](https://chromium.googlesource.com/chromium/src/+/refs/heads/main/docs/linux/cast_build_instructions.md)).  
So we cannot ship a fully certified, identical Cast device. We can only approximate one using open-source Cast protocol implementations.

## How Cast discovery works

- Devices are discovered via **mDNS** with service type **`_googlecast._tcp`**.
- Senders (YouTube Music, Spotify, Chrome) look for that service and read **TXT** records (e.g. `fn` = friendly name, port).
- Connection is **TLS on port 8009** (Chromecast) or the port advertised in mDNS.
- After connecting, the sender launches a **receiver app** (e.g. Default Media Receiver, or app-specific like YouTube’s) and sends **LOAD** / **media** messages.

So for the Pi to appear in the cast list we need:

1. **Advertise** `_googlecast._tcp` (or compatible) on the LAN.
2. **Accept TLS** on the expected port and speak the **Cast v2 protocol** (virtual connections, LAUNCH, LOAD, etc.).
3. **Support at least one receiver app** (e.g. Default Media Receiver) so that when the sender sends a LOAD with a URL, we can play it.

## Open-source option: Open Screen (libcast)

The **Open Screen** project ([Chromium Open Screen](https://chromium.googlesource.com/openscreen/)) provides:

- **Cast protocols**: discovery, application control, media streaming.
- **`cast_receiver`** (standalone receiver): reference implementation that:
  - Uses **DNS-SD/mDNS** for discovery (advertises the receiver).
  - Listens on **TLS** (in the code seen, port **8010** is used; Chromecast uses **8009**—compatibility with all senders may need verification).
  - Implements Cast **receiver** and **streaming** (decode/playback with FFmpeg + SDL2, or a dummy player without those libs).

Relevant docs:

- [libcast README](https://chromium.googlesource.com/openscreen/+/HEAD/cast/README.md)
- [Standalone receiver / external libs](https://chromium.googlesource.com/openscreen/+/HEAD/cast/docs/external_libraries.md)
- [Build (Open Screen README)](https://chromium.googlesource.com/openscreen/+/HEAD/README.md)

Build is **GN + Ninja**, with optional **depot_tools** for `fetch openscreen`. Dependencies for real playback: **FFmpeg**, **SDL2**, **libopus**, **libvpx** (and optionally **libaom** for AV1). The receiver can also be built with a **dummy player** (no decode/playback) for protocol testing.

## Compatibility with YouTube Music / Spotify

- **Discovery**: If the Open Screen receiver advertises a service type and TXT records that Cast senders understand, it can **show up in the cast list** (same network, no client setup).
- **App support**: YouTube Music and Spotify often use **custom receiver apps** (their own app IDs), not only the Default Media Receiver. So:
  - The device may **appear** in the cast list.
  - Tapping it and casting might **succeed** if the sender falls back to Default Media Receiver or sends a LOAD we can handle.
  - Or it might **fail** or be **limited** if the sender insists on launching an app we don’t implement.

So “appear in cast button” is the target; “full YT Music/Spotify behavior” is best-effort and may require testing and possibly protocol/port adjustments (e.g. 8009 vs 8010, service name).

## Other options considered

- **node-castv2** (Node): Has a Server implementation, but the project notes that **device authentication** blocks using it as a full Cast receiver; not suitable as-is for “show in cast list and play.”
- **NymphCast**: Uses its own protocol and discovery (NyanSD, port 4004); does **not** advertise `_googlecast._tcp`, so it does **not** appear in the standard Cast picker (and would require the NymphCast app on the client).
- **Chromium `cast_shell`**: Full Chromium checkout (100GB+, heavy build); explicitly not a full Chromecast equivalent; not practical for a small RPi-focused project.

## Conclusion

The only viable path for “RPi speaker in the cast button with no client setup” is to **build and run the Open Screen standalone Cast receiver** on the Pi, with:

- **Audio output** pointed at the aux/3.5 mm device (ALSA/PulseAudio).
- **Discovery enabled** so the receiver advertises on the LAN.
- **Credentials** generated (e.g. `-g`) and then used (`-p`, `-d`) for TLS.

This repo provides **scripts and instructions** to build that receiver on Raspberry Pi OS and run it so you can test with YouTube Music, Spotify, and other Cast apps on phones/laptops/tablets without installing extra client software.
