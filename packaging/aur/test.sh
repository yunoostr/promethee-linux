#!/usr/bin/env bash
# Builds, installs, starts and removes the AUR package in a clean Arch container.
# Usage: docker run --rm --shm-size=1g -v "$PWD:/repo:ro" archlinux:latest bash /repo/packaging/aur/test.sh [version]
set -euo pipefail

pacman -Syu --noconfirm --needed base-devel git namcap xorg-server-xvfb xorg-xauth >/dev/null
useradd -m builder
# makepkg clones a commit: copy the checkout and commit it, so uncommitted edits get tested too.
cp -a /repo /src && chown -R builder /src
su builder -c 'cd /src && git -c user.name=test -c user.email=test@localhost commit -qam test --allow-empty'
commit=$(su builder -c 'git -C /src rev-parse HEAD')

mkdir /pkg && cp /src/packaging/aur/PKGBUILD /pkg/ && chown -R builder /pkg
sed -i -e "s|^source=.*|source=(\"promethee-linux::git+file:///src#commit=$commit\")|" /pkg/PKGBUILD
[ -z "${1:-}" ] || sed -i "s/^pkgver=.*/pkgver=$1/" /pkg/PKGBUILD

# shellcheck source=/dev/null disable=SC2154
(source /pkg/PKGBUILD && pacman -S --noconfirm --needed "${depends[@]}" "${makedepends[@]}" >/dev/null)
su builder -c 'cd /pkg && makepkg --noconfirm' >/pkg/makepkg.log 2>&1 || { tail -30 /pkg/makepkg.log; exit 1; }
pacman -U --noconfirm /pkg/*.pkg.tar.zst >/dev/null

# active-win ships a macOS binary that namcap mistakes for Java classes.
errors=$(namcap /pkg/PKGBUILD /pkg/*.pkg.tar.zst | grep ' E: ' | grep -v java-runtime || true)
[ -z "$errors" ] || { echo "FAIL: namcap"; echo "$errors"; exit 1; }

# --no-sandbox: containers block the namespaces Chromium's sandbox needs.
s=0; su builder -c 'timeout 20 xvfb-run -a promethee --no-sandbox --enable-logging=stderr' >/pkg/app.log 2>&1 || s=$?
if grep -q -E 'Uncaught|Failed to fetch dynamically imported module' /pkg/app.log; then tail -15 /pkg/app.log; echo "FAIL: the UI hit a script error"; exit 1; fi
[ $s = 124 ] || { tail -15 /pkg/app.log; echo "FAIL: exited with $s"; exit 1; }
[ ! -e /home/builder/.local/share/applications/promethee.desktop ] || { echo "FAIL: launcher wrote its own entry"; exit 1; }

pacman -R --noconfirm promethee >/dev/null
[ ! -e /usr/lib/promethee ] || { echo "FAIL: /usr/lib/promethee left behind"; exit 1; }
echo "OK: package $(sed -n 's/^pkgver=//p' /pkg/PKGBUILD) builds, starts for 20s and uninstalls cleanly"
