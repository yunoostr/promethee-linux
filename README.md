<p align="center">
  <img alt="Now on Linux — the same focus, on your own machine" src=".github/assets/banner.jpg" width="100%">
</p>

<h1 align="center">Promethee for Linux</h1>

<p align="center">
  <strong>Run <a href="https://www.promethee.io">Promethee</a> on Linux.</strong><br />
  One script turns the official release into a Linux app, on your own machine.<br />
  Community-made, unofficial, and nothing redistributed.
</p>

<p align="center">
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-c2703d?labelColor=1c1917"></a>
  <img alt="Linux x64 and arm64" src="https://img.shields.io/badge/linux-x64%20%7C%20arm64-c2703d?logo=linux&logoColor=white&labelColor=1c1917">
  <a href="../../actions/workflows/check-release.yml"><img alt="Latest Promethee release tested on Linux" src="https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/yunoostr/promethee-linux/main/.github/status.json"></a>
  <img alt="Electron 43.8.3" src="https://img.shields.io/badge/electron-43.8.3-c2703d?logo=electron&logoColor=white&labelColor=1c1917">
  <img alt="Unofficial" src="https://img.shields.io/badge/status-unofficial-78716c?labelColor=1c1917">
</p>

<p align="center">
  <a href="#-quick-start"><strong>Get started »</strong></a>
  <br />
  <br />
  <a href="https://www.promethee.io">Promethee</a>
  -
  <a href="#%EF%B8%8F-how-it-works">How it works</a>
  -
  <a href="../../issues">Report your distro</a>
  -
  <a href="https://promethee-lab.y2.engineer">Promethee Lab</a>
</p>

<br />

<p align="center"><strong>Built for your distro:</strong></p>
<p align="center">
  <img alt="Debian" title="Debian 13 (tested)" src="https://cdn.simpleicons.org/debian" width="40">
  <img alt="Ubuntu" title="Ubuntu 24.10+" src="https://cdn.simpleicons.org/ubuntu" width="40">
  <img alt="Fedora" title="Fedora" src="https://cdn.simpleicons.org/fedora" width="40">
  <img alt="Arch Linux" title="Arch Linux" src="https://cdn.simpleicons.org/archlinux" width="40">
  <img alt="Linux Mint" title="Linux Mint" src="https://cdn.simpleicons.org/linuxmint" width="40">
  <img alt="openSUSE" title="openSUSE Tumbleweed" src="https://cdn.simpleicons.org/opensuse" width="40">
</p>
<p align="center"><sub>tested on Debian 13 - any distro with gcc 14 or newer should work - <a href="../../issues">tell us how it goes</a></sub></p>

<br />

## 🔥 Why

Promethee turns your focus sessions into a visual history of your progress. It ships for macOS and Windows,
and Linux users have been left at the door. Not anymore.

<p align="center">
  <img alt="Promethee signed in on Debian 13, showing the feed" src=".github/assets/screenshot.jpg" width="100%">
</p>

<table>
  <tr>
    <td width="33%" valign="top">
      <img alt="Explore tab on Linux" src=".github/assets/app-explore.jpg"><br />
      <strong>🔎 Explore</strong><br />
      <sub>Guilds, people and the apps the community focuses with</sub>
    </td>
    <td width="33%" valign="top">
      <img alt="Leaderboard on Linux" src=".github/assets/app-rank.jpg"><br />
      <strong>🏆 Rank</strong><br />
      <sub>Live season leaderboard and your league</sub>
    </td>
    <td width="33%" valign="top">
      <img alt="Analytics tab on Linux" src=".github/assets/app-analytics.jpg"><br />
      <strong>📊 Analytics</strong><br />
      <sub>Your week, your goals, your streak</sub>
    </td>
  </tr>
</table>
<p align="center"><sub>A real account, signed in on Debian 13. Other members' names and posts are blurred.</sub></p>

## ⚡ Quick start

```bash
# Debian / Ubuntu: sudo apt install curl unzip nodejs npm python3 make g++
git clone https://github.com/yunoostr/promethee-linux && cd promethee-linux
./promethee
```

That's it. The first run builds the app (a few minutes), every later run starts it right away.

**Updates are automatic.** On each launch, `./promethee` checks for a new Promethee release in the background,
builds it next to the current one and tells you when it's ready. The new version opens on your next launch,
and the previous one is kept in case you need to go back.

**It shows up in your app launcher.** `./promethee` adds Promethee to your launcher (and lets `promethee://` links open it).
Remove it with `./promethee --uninstall-desktop`, or set `PROMETHEE_NO_DESKTOP=1` to never add it.

<sub>Needs <code>curl</code>, <code>unzip</code>, <code>node</code>, <code>python3</code>, <code>make</code> and <code>g++</code> 14+ (Electron 43's headers need a recent compiler). On Ubuntu 23.10+, Chromium's sandbox needs admin rights once per version: <code>./promethee</code> asks for your password when that's the case.</sub>

<sub>Promethee keeps you signed in through your desktop keyring. GNOME and KDE have one out of the box; on sway, i3 or Hyprland, run <code>gnome-keyring</code> (or KeePassXC's Secret Service) and <code>./promethee</code> takes care of the rest. Without a keyring you'll have to sign in again at each launch.</sub>

## 🛠️ How it works

Promethee is an Electron app, so almost all of it already runs on Linux. `build.sh` takes the official
macOS release, swaps the few pieces that only fit macOS, and puts it inside the Linux build of Electron.
Nothing from Promethee lives in this repo: everything is downloaded from Promethee's own release page, on your machine.

<table>
  <tr>
    <td width="33%" valign="top">
      <img alt="Download" src=".github/assets/step-download.jpg"><br />
      <strong>1. Download</strong><br />
      <sub>Fetches the official macOS build and reads which Electron version it was made with</sub>
    </td>
    <td width="33%" valign="top">
      <img alt="Patch" src=".github/assets/step-patch.jpg"><br />
      <strong>2. Patch</strong><br />
      <sub>Drops the macOS-only module and recompiles the SQLite database driver for Linux</sub>
    </td>
    <td width="33%" valign="top">
      <img alt="Focus" src=".github/assets/step-focus.jpg"><br />
      <strong>3. Focus</strong><br />
      <sub>Puts the app inside the matching Linux Electron, with a launcher. Start a session</sub>
    </td>
  </tr>
</table>

## ✅ What works

| Feature | Status |
|---|---|
| Sign in with email code | ✅ |
| Staying signed in after a restart | ✅ stored in your desktop keyring (GNOME Keyring, KWallet, KeePassXC…) |
| Feed, Explore, Rank, Tasks, Analytics | ✅ live data from your account |
| Direct messages (realtime) | ✅ |
| Guild chat rooms (realtime) | ✅ |
| Starting a focus session | ❔ not tested yet |
| Local database (SQLite, encrypted) | ✅ recompiled for Linux |
| Active window tracking & app blocker | ⚠️ X11 only (via `xprop`), not Wayland yet |
| macOS vibrancy, Windows virtual desktops | ➖ not applicable |
| Auto-update | ✅ handled by `./promethee`, applied on next launch |

## 🐳 Try it without Linux

The Dockerfile builds the app on Debian 13 and launches it for 20 seconds on a virtual screen:

```bash
docker build -t promethee-linux .
docker run --rm --shm-size=1g promethee-linux
```

<sub><code>--shm-size=1g</code> matters: Chromium needs more shared memory than Docker's default 64 MB.</sub>

## 🤝 Contributing

The most useful thing you can do right now is **try it on your distro** and [open an issue](../../issues)
with your distro, desktop (X11 or Wayland) and what worked. Ideas welcome on the roadmap:

- [x] A `.desktop` entry, added by `./promethee`
- [ ] AppImage
- [ ] AUR package
- [ ] Wayland window detection
- [x] A daily check that builds and tests every new Promethee release on x64 and arm64 (nothing is published)

## ⚖️ Legal

This project is **not affiliated with or endorsed by Promethee**. It does not contain or redistribute any of
Promethee's code: `build.sh` downloads the official release from Promethee's own GitHub releases and adapts it
locally, for interoperability. Please don't publish the built app. Promethee is proprietary software owned by
its authors.

## 🙏 Credits

- [Promethee](https://www.promethee.io), for building something worth porting
- [Promethee Lab](https://promethee-lab.y2.engineer) by [y2](https://x.com/y2_dev), whose posters make up every image in this README
- [Electron](https://www.electronjs.org) and [better-sqlite3-multiple-ciphers](https://github.com/m4heshd/better-sqlite3-multiple-ciphers)

<br />

<p align="center">
  <img alt="Show up on every distro" src=".github/assets/footer.jpg" width="100%">
</p>

<p align="center"><sub>MIT for the scripts in this repo - made by the Promethee community, for the Promethee community</sub></p>
