#!/usr/bin/env bash
# Forward a macOS USB serial device to a TCP port so the Dev Container can access it.
#
# Usage:
#   ./usb-forward.sh                          # defaults: /dev/tty.usbmodem1101, port 3333, 115200 baud
#   ./usb-forward.sh /dev/tty.usbserial-0001  # custom device
#   ./usb-forward.sh /dev/tty.usbmodem1101 3333 115200  # all explicit

set -euo pipefail

DEVICE="${1:-/dev/tty.usbmodem1101}"
PORT="${2:-3333}"
BAUD="${3:-115200}"

if [[ ! -e "$DEVICE" ]]; then
  echo "Error: Device $DEVICE not found."
  echo "Available serial devices:"
  ls /dev/tty.usb* 2>/dev/null || echo "  (none)"
  exit 1
fi

echo "Forwarding $DEVICE (${BAUD} baud) → TCP port $PORT"
echo "Press Ctrl+C to stop."
exec socat TCP-LISTEN:"$PORT",reuseaddr,fork FILE:"$DEVICE",b"$BAUD",raw,echo=0
