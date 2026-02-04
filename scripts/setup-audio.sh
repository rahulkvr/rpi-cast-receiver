#!/usr/bin/env bash
# Point Raspberry Pi audio output to the aux (3.5 mm) jack (or HDMI / USB).
# Run once; optionally run raspi-config for a menu.

set -e

echo "Raspberry Pi audio setup (aux / 3.5 mm jack)"
echo "For a menu instead, run: sudo raspi-config → System Options → Audio"
echo ""

# Force 3.5 mm headphone jack (Raspberry Pi OS)
# amixer is for ALSA; Raspberry Pi OS often uses the headphone output.
if command -v amixer &>/dev/null; then
  # Unmute and set headphone (aux) as output if your card has it
  amixer -c 0 set Headphone unmute 2>/dev/null || true
  amixer -c 0 set Headphone 100% 2>/dev/null || true
  echo "ALSA: Headphone (aux) unmuted and volume set."
fi

# If using PulseAudio
if command -v pactl &>/dev/null; then
  SINK=$(pactl get-default-sink 2>/dev/null || true)
  echo "Current PulseAudio sink: $SINK"
  echo "To list sinks: pactl list short sinks"
  echo "To set default: pactl set-default-sink <name>"
fi

echo ""
echo "Test with: aplay /usr/share/sounds/alsa/Front_Center.wav"
echo "If no sound, run: sudo raspi-config → System Options → Audio → Headphones"
