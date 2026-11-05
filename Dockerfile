# svn-gaming: browser-based Linux desktop (XFCE + noVNC) with Wine and the Windows Steam installer.
# The app's web URL opens the desktop. Set VNC_PASSWORD (max 8 chars) as an environment variable.
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC

RUN apt-get update && apt-get install -y --no-install-recommends \
        xfce4 xfce4-terminal dbus-x11 xauth x11-xserver-utils \
        tigervnc-standalone-server tigervnc-tools novnc websockify \
        pulseaudio wget curl ca-certificates xz-utils gnupg fonts-dejavu-core \
        libfreetype6 libfontconfig1 libgl1 libgl1-mesa-dri libvulkan1 libpulse0 \
        libasound2t64 libgnutls30t64 libsdl2-2.0-0 \
    && rm -rf /var/lib/apt/lists/* \
    && ln -sf /usr/share/novnc/vnc.html /usr/share/novnc/index.html

# Wine 10 WoW64. On ARM hosts, Box64 is added to run it; on x86_64 it runs natively.
RUN set -e; \
    if [ "$(uname -m)" = "aarch64" ]; then \
        wget -qO- https://pi-apps-coders.github.io/box64-debs/KEY.gpg \
          | gpg --dearmor -o /usr/share/keyrings/box64-archive-keyring.gpg; \
        echo "deb [signed-by=/usr/share/keyrings/box64-archive-keyring.gpg] https://Pi-Apps-Coders.github.io/box64-debs/debian ./" \
          > /etc/apt/sources.list.d/box64.list; \
        apt-get update && apt-get install -y --no-install-recommends box64-generic-arm && rm -rf /var/lib/apt/lists/*; \
        RUNNER="box64 "; \
    else \
        RUNNER=""; \
    fi; \
    wget -qO /tmp/wine.tar.xz https://github.com/Kron4ek/Wine-Builds/releases/download/10.0/wine-10.0-amd64-wow64.tar.xz; \
    tar -xf /tmp/wine.tar.xz -C /opt && rm /tmp/wine.tar.xz; \
    mv /opt/wine-10.0-amd64* /opt/wine; \
    printf '#!/bin/sh\nexec %s/opt/wine/bin/wine "$@"\n' "$RUNNER" > /usr/local/bin/wine; \
    printf '#!/bin/sh\nexec %s/opt/wine/bin/wineserver "$@"\n' "$RUNNER" > /usr/local/bin/wineserver; \
    chmod +x /usr/local/bin/wine /usr/local/bin/wineserver

RUN useradd -m -s /bin/bash gamer
USER gamer
WORKDIR /home/gamer

# Desktop session + Steam installer and launcher on the desktop
RUN mkdir -p ~/.vnc ~/Desktop/Gaming \
    && printf '#!/bin/sh\nunset SESSION_MANAGER DBUS_SESSION_BUS_ADDRESS\npulseaudio --start --exit-idle-time=-1 2>/dev/null\nexec dbus-launch --exit-with-session startxfce4\n' > ~/.vnc/xstartup \
    && chmod +x ~/.vnc/xstartup \
    && wget -qO ~/Desktop/Gaming/SteamSetup.exe https://cdn.akamai.steamstatic.com/client/installer/SteamSetup.exe \
    && printf '#!/bin/sh\nexport BOX64_DYNAREC_STRONGMEM=1\nwine ~/Desktop/Gaming/SteamSetup.exe\n' > ~/Desktop/install-steam.sh \
    && chmod +x ~/Desktop/install-steam.sh

COPY --chown=gamer:gamer docker/start.sh /home/gamer/start.sh

ENV PORT=8000
EXPOSE 8000

CMD ["bash", "/home/gamer/start.sh"]
