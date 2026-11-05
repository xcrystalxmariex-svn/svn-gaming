# svn-gaming

One-file installers that build a Linux desktop with Wine and the Windows Steam client, either inside Termux on an Android phone or on a plain Ubuntu cloud server. Run one script, get a desktop you can reach over VNC (phone) or a web browser (server), then install Steam from it.

## What's in the repo

| File | Runs on | What it builds |
|---|---|---|
| `setup-termux.sh` | Termux (F-Droid build) on ARM64 Android | Ubuntu PRoot, XFCE, TigerVNC, Box64, Wine 10, Steam installer |
| `setup-ubuntu-server.sh` | Ubuntu 22.04+ server, x86_64 or arm64 | XFCE, TigerVNC, noVNC browser viewer, Wine 10 (Box64 added on ARM), Steam installer |

Both scripts ask for a VNC password once at the start and can be re-run safely; finished steps are skipped or repeated without harm.

## Android phone (Termux)

Use Termux from F-Droid. The Google Play build is outdated and breaks package installs.

```bash
curl -LO https://raw.githubusercontent.com/xcrystalxmariex-svn/svn-gaming/main/setup-termux.sh
bash setup-termux.sh
```

Expect 20 to 40 minutes and 4 to 6 GB of storage. Android will show a storage permission popup once.

To use it:

1. Run `bash ~/desktop-start.sh` and leave that Termux session open.
2. In a VNC viewer app (RealVNC Viewer, bVNC), connect to `localhost:5901` with your VNC password.
3. On the desktop, open a terminal and run `~/Desktop/install-steam.sh`.

## Cloud server (Ubuntu)

Run as a normal user that has sudo.

```bash
curl -LO https://raw.githubusercontent.com/xcrystalxmariex-svn/svn-gaming/main/setup-ubuntu-server.sh
bash setup-ubuntu-server.sh
```

To use it:

1. Open TCP port 6080 in the server's firewall (on Oracle Cloud: the subnet's security list and the instance's iptables).
2. Run `bash ~/desktop-start.sh`.
3. Browse to `http://<server-ip>:6080/vnc.html` and enter your VNC password.
4. On the desktop, open a terminal and run `~/Desktop/install-steam.sh`.
5. Stop it with `bash ~/desktop-stop.sh`.

To keep the viewer off the public internet, start it with `NOVNC_BIND=127.0.0.1 bash ~/desktop-start.sh` and reach it through an SSH tunnel: `ssh -L 6080:localhost:6080 <user>@<server-ip>`, then open `http://localhost:6080/vnc.html`.

## Known limits

- **No GPU, no speed.** Without a GPU driver, every frame is drawn by the CPU. 2D and light games can work; 3D games will crawl. Phones with Mali GPUs (most MediaTek and Exynos chips) cannot use the Turnip driver, which only supports Adreno.
- **Memory.** Steam's Windows client wants several GB of free RAM. Phones with 4 GB or less will likely crash or stall.
- **Anti-cheat.** Games protected by Easy Anti-Cheat or BattlEye, including Brawlhalla, will most likely refuse to run under Wine with Box64. Proton's anti-cheat support only exists in the Linux Steam client.
- **Steam's built-in browser** is the part most likely to break or run slowly under translation.
- **Latency.** VNC over the internet adds input lag, which matters for fighting games.

For Brawlhalla specifically, the native Android app or GeForce NOW are the reliable ways to play.

## Sources the scripts download

- Box64 packages: [Pi-Apps-Coders box64-debs](https://github.com/Pi-Apps-Coders/box64-debs) (`box64-android` in Termux, `box64-generic-arm` on ARM servers)
- Wine: [Kron4ek Wine-Builds 10.0 WoW64](https://github.com/Kron4ek/Wine-Builds/releases/tag/10.0)
- Steam: the official Windows `SteamSetup.exe` from Valve's CDN

## Push this repo to GitHub

Create an empty repo named `svn-gaming` on GitHub first (no README, no license), then from the folder:

```bash
cd svn-gaming
git init
git add .
git commit -m "Initial commit: Termux and Ubuntu server setup scripts"
git branch -M main
git remote add origin https://github.com/xcrystalxmariex-svn/svn-gaming.git
git push -u origin main
```
