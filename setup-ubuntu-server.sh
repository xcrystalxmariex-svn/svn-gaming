#!/usr/bin/env bash
# svn-gaming: setup-ubuntu-server.sh
# Plain Ubuntu cloud server (x86_64 or arm64) -> XFCE + VNC + noVNC (browser) + Wine (+ Box64 on ARM) + Steam (Windows) installer
# Run as a normal user with sudo:  bash setup-ubuntu-server.sh
set -e

SUDO=""; [ "$(id -u)" -ne 0 ] && SUDO="sudo"
ARCH="$(uname -m)"
export DEBIAN_FRONTEND=noninteractive

read -rsp "Pick a VNC password (6-8 chars): " VNCPW; echo
[ ${#VNCPW} -ge 6 ] || { echo "Needs at least 6 characters."; exit 1; }

echo "== [1/5] Base packages ($ARCH)"
$SUDO apt update && $SUDO apt upgrade -y
$SUDO apt install -y xfce4 xfce4-terminal tigervnc-standalone-server tigervnc-tools \
  dbus-x11 novnc websockify pulseaudio wget curl gnupg ca-certificates xz-utils

for p in libfreetype6 libfontconfig1 libgl1 libgl1-mesa-dri libvulkan1 libpulse0 \
         libasound2t64 libasound2 libgnutls30t64 libgnutls30 libsdl2-2.0-0; do
  $SUDO apt install -y "$p" >/dev/null 2>&1 || true
done

echo "== [2/5] x86 translation"
if [ "$ARCH" = "aarch64" ]; then
  wget -qO- https://pi-apps-coders.github.io/box64-debs/KEY.gpg \
    | $SUDO gpg --dearmor --yes -o /usr/share/keyrings/box64-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/box64-archive-keyring.gpg] https://Pi-Apps-Coders.github.io/box64-debs/debian ./" \
    | $SUDO tee /etc/apt/sources.list.d/box64.list >/dev/null
  $SUDO apt update && $SUDO apt install -y box64-generic-arm
  RUN="box64 "
else
  echo "x86_64 detected: Wine runs natively, no Box64 needed."
  RUN=""
fi

echo "== [3/5] Wine 10 WoW64"
if [ ! -x /opt/wine/bin/wine ]; then
  wget -O /tmp/wine.tar.xz https://github.com/Kron4ek/Wine-Builds/releases/download/10.0/wine-10.0-amd64-wow64.tar.xz
  $SUDO tar -xf /tmp/wine.tar.xz -C /opt && rm /tmp/wine.tar.xz
  $SUDO mv /opt/wine-10.0-amd64* /opt/wine
fi
printf '#!/bin/sh\nexec %s/opt/wine/bin/wine "$@"\n' "$RUN"       | $SUDO tee /usr/local/bin/wine >/dev/null
printf '#!/bin/sh\nexec %s/opt/wine/bin/wineserver "$@"\n' "$RUN" | $SUDO tee /usr/local/bin/wineserver >/dev/null
$SUDO chmod +x /usr/local/bin/wine /usr/local/bin/wineserver

echo "== [4/5] VNC desktop"
mkdir -p ~/.vnc
printf '%s\n' "$VNCPW" | vncpasswd -f > ~/.vnc/passwd && chmod 600 ~/.vnc/passwd
cat > ~/.vnc/xstartup <<'X'
#!/bin/sh
unset SESSION_MANAGER DBUS_SESSION_BUS_ADDRESS
pulseaudio --start --exit-idle-time=-1 2>/dev/null
exec dbus-launch --exit-with-session startxfce4
X
chmod +x ~/.vnc/xstartup

echo "== [5/5] Steam installer + launchers"
mkdir -p ~/Desktop/Gaming
wget -qO ~/Desktop/Gaming/SteamSetup.exe https://cdn.akamai.steamstatic.com/client/installer/SteamSetup.exe
cat > ~/Desktop/install-steam.sh <<'S'
#!/bin/sh
export BOX64_DYNAREC_STRONGMEM=1
wine ~/Desktop/Gaming/SteamSetup.exe
S
chmod +x ~/Desktop/install-steam.sh

cat > ~/desktop-start.sh <<'L'
#!/usr/bin/env bash
# Starts the desktop and the browser viewer.
# NOVNC_BIND=127.0.0.1 keeps it private (use an SSH tunnel); default 0.0.0.0 is reachable from the internet.
BIND="${NOVNC_BIND:-0.0.0.0}"
PORT="${NOVNC_PORT:-6080}"
vncserver -kill :1 >/dev/null 2>&1 || true
vncserver :1 -geometry 1280x720 -depth 24 -localhost yes
pkill -f "websockify.*$PORT" 2>/dev/null || true
nohup websockify --web /usr/share/novnc "$BIND:$PORT" localhost:5901 >/tmp/novnc.log 2>&1 &
echo "Desktop up. Open http://<server-ip>:$PORT/vnc.html in a browser and enter your VNC password."
L
chmod +x ~/desktop-start.sh

cat > ~/desktop-stop.sh <<'L'
#!/usr/bin/env bash
vncserver -kill :1 >/dev/null 2>&1 || true
pkill -f websockify 2>/dev/null || true
echo "Desktop stopped."
L
chmod +x ~/desktop-stop.sh

echo
echo "Done. Start:  bash ~/desktop-start.sh   Stop:  bash ~/desktop-stop.sh"
echo "Open port ${NOVNC_PORT:-6080}/tcp in your cloud firewall, then browse to http://<server-ip>:${NOVNC_PORT:-6080}/vnc.html"
echo "On the desktop, open a terminal and run:  ~/Desktop/install-steam.sh"
