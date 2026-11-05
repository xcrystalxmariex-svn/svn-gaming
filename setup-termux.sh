#!/data/data/com.termux/files/usr/bin/bash
# svn-gaming: setup-termux.sh
# Termux (F-Droid build) -> Ubuntu PRoot + XFCE + VNC + Box64 + Wine + Steam (Windows) installer
# Run with: bash setup-termux.sh
set -e

read -rsp "Pick a VNC password (6-8 chars): " VNCPW; echo
[ ${#VNCPW} -ge 6 ] || { echo "Needs at least 6 characters."; exit 1; }

echo "== [1/4] Termux base packages"
pkg update -y && pkg upgrade -y
pkg install -y x11-repo
pkg install -y proot-distro pulseaudio
[ -d ~/storage ] || termux-setup-storage

echo "== [2/4] Ubuntu container"
[ -d "$PREFIX/var/lib/proot-distro/installed-rootfs/ubuntu" ] || proot-distro install ubuntu

echo "== [3/4] Desktop, VNC, Box64, Wine, Steam installer (this part takes a while)"
proot-distro login ubuntu -- bash -s -- "$VNCPW" <<'UBU'
set -e
VNCPW="$1"
export DEBIAN_FRONTEND=noninteractive

apt update && apt upgrade -y
apt install -y xfce4 xfce4-terminal tigervnc-standalone-server tigervnc-tools \
  dbus-x11 wget curl gnupg ca-certificates xz-utils

# Native ARM libs Box64 hands Wine's calls to (names differ by Ubuntu version, so misses are skipped)
for p in libfreetype6 libfontconfig1 libgl1 libgl1-mesa-dri libvulkan1 libpulse0 \
         libasound2t64 libasound2 libgnutls30t64 libgnutls30 libsdl2-2.0-0; do
  apt install -y "$p" >/dev/null 2>&1 || true
done

# Box64 (Android PRoot build)
wget -qO- https://pi-apps-coders.github.io/box64-debs/KEY.gpg \
  | gpg --dearmor --yes -o /usr/share/keyrings/box64-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/box64-archive-keyring.gpg] https://Pi-Apps-Coders.github.io/box64-debs/debian ./" \
  > /etc/apt/sources.list.d/box64.list
apt update && apt install -y box64-android

# Wine 10 WoW64 (runs 32-bit Windows apps without box86)
if [ ! -x /opt/wine/bin/wine ]; then
  wget -O /tmp/wine.tar.xz https://github.com/Kron4ek/Wine-Builds/releases/download/10.0/wine-10.0-amd64-wow64.tar.xz
  tar -xf /tmp/wine.tar.xz -C /opt && rm /tmp/wine.tar.xz
  mv /opt/wine-10.0-amd64* /opt/wine
fi
printf '#!/bin/sh\nexec box64 /opt/wine/bin/wine "$@"\n'       > /usr/local/bin/wine
printf '#!/bin/sh\nexec box64 /opt/wine/bin/wineserver "$@"\n' > /usr/local/bin/wineserver
chmod +x /usr/local/bin/wine /usr/local/bin/wineserver

# VNC desktop
mkdir -p ~/.vnc
printf '%s\n' "$VNCPW" | vncpasswd -f > ~/.vnc/passwd && chmod 600 ~/.vnc/passwd
cat > ~/.vnc/xstartup <<'X'
#!/bin/sh
unset SESSION_MANAGER DBUS_SESSION_BUS_ADDRESS
export PULSE_SERVER=127.0.0.1
exec dbus-launch --exit-with-session startxfce4
X
chmod +x ~/.vnc/xstartup

# Steam (Windows client) installer + launcher on the desktop
mkdir -p ~/Desktop/Gaming
wget -qO ~/Desktop/Gaming/SteamSetup.exe https://cdn.akamai.steamstatic.com/client/installer/SteamSetup.exe
cat > ~/Desktop/install-steam.sh <<'S'
#!/bin/sh
export PULSE_SERVER=127.0.0.1
export BOX64_DYNAREC_STRONGMEM=1
wine ~/Desktop/Gaming/SteamSetup.exe
S
chmod +x ~/Desktop/install-steam.sh
UBU

echo "== [4/4] Audio + launcher"
PA='pulseaudio --start --exit-idle-time=-1 --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" 2>/dev/null'
grep -q "module-native-protocol-tcp" ~/.bashrc 2>/dev/null || echo "$PA" >> ~/.bashrc

cat > ~/desktop-start.sh <<'L'
#!/data/data/com.termux/files/usr/bin/bash
pulseaudio --start --exit-idle-time=-1 --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" 2>/dev/null
echo "Starting desktop. Open your VNC app -> localhost:5901. Leave this session open; Ctrl+C stops it."
proot-distro login ubuntu -- bash -c 'vncserver -kill :1 >/dev/null 2>&1; vncserver :1 -geometry 1280x720 -depth 24 -localhost yes; tail -f /dev/null'
L
chmod +x ~/desktop-start.sh

echo
echo "Done. Start the desktop any time with:  bash ~/desktop-start.sh"
echo "Then on the desktop open a terminal and run:  ~/Desktop/install-steam.sh"
