#!/bin/bash
# Container entrypoint: starts the VNC desktop, then serves it in the browser on $PORT.
set -e

PORT="${PORT:-8000}"
GEOM="${VNC_GEOMETRY:-1280x720}"

if [ -z "$VNC_PASSWORD" ]; then
  VNC_PASSWORD="$(head -c 32 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 8)"
  echo "No VNC_PASSWORD set. Generated one for this run: $VNC_PASSWORD"
fi

mkdir -p ~/.vnc ~/.config/tigervnc
printf '%s\n' "$VNC_PASSWORD" | vncpasswd -f > ~/.vnc/passwd
chmod 600 ~/.vnc/passwd
cp ~/.vnc/passwd ~/.config/tigervnc/passwd
cp ~/.vnc/xstartup ~/.config/tigervnc/xstartup

# Clear stale locks from a previous run of the same container
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1 2>/dev/null || true

vncserver :1 -geometry "$GEOM" -depth 24 -localhost yes

echo "Desktop running. Open the app URL in a browser and enter the VNC password."
exec websockify --web /usr/share/novnc "0.0.0.0:$PORT" localhost:5901
