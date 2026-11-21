#!/usr/bin/env bash
# Pushes PKGBUILD + .SRCINFO to the AUR for a tested Promethee version and promethee-linux commit.
# Usage: AUR_SSH_KEY=<private key> packaging/aur/publish.sh <version> <commit>   (needs docker, full git history)
# AUR_REMOTE overrides the AUR git URL (tests push to a local bare repo).
set -euo pipefail
version=$1 commit=$2
here=$(cd "$(dirname "$0")" && pwd)
repo=$(git -C "$here" rev-parse --show-toplevel)
[ -n "${AUR_SSH_KEY:-}" ] || { echo "::notice::AUR_SSH_KEY is not set: nothing published to the AUR"; exit 0; }

ssh_dir=$(mktemp -d) aur=$(mktemp -d)
trap 'rm -rf "$ssh_dir" "$aur"' EXIT
printf '%s\n' "$AUR_SSH_KEY" > "$ssh_dir/key" && chmod 600 "$ssh_dir/key"
# Pinned: matches the fingerprint published on https://aur.archlinux.org (SHA256:RFzBCUItH9LZS0cKB5UE6ceAYhBD5C8GeOBip8Z11+4).
echo 'aur.archlinux.org ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEuBKrPzbawxA/k2g6NcyV5jmqwJ2s+zpgZGZ7tpLIcN' > "$ssh_dir/known_hosts"
export GIT_SSH_COMMAND="ssh -i $ssh_dir/key -o UserKnownHostsFile=$ssh_dir/known_hosts -o IdentitiesOnly=yes"
git clone -q "${AUR_REMOTE:-ssh://aur@aur.archlinux.org/promethee.git}" "$aur"

field() { sed -n "s/^$1=\([^ ]*\).*/\1/p" "$aur/PKGBUILD" 2>/dev/null; }
pkgrel=1
if [ "$(field pkgver)" = "$version" ]; then
  # Same Promethee release: republish only when what the package builds changed.
  if git -C "$repo" diff --quiet "$(field _commit)" "$commit" -- build.sh promethee patches packaging/aur/PKGBUILD 2>/dev/null; then
    echo "AUR already has Promethee $version for this launcher"; exit 0
  fi
  pkgrel=$(( $(field pkgrel) + 1 ))
fi

sed -e "s/^pkgver=.*/pkgver=$version/" -e "s/^pkgrel=.*/pkgrel=$pkgrel/" -e "s/^_commit=[^ ]*/_commit=$commit/" \
  "$here/PKGBUILD" > "$aur/PKGBUILD"
docker run --rm -i archlinux:latest bash -c \
  'useradd -m builder && cd /home/builder && cat > PKGBUILD && su builder -c "makepkg --printsrcinfo"' \
  < "$aur/PKGBUILD" > "$aur/.SRCINFO"

git -C "$aur" add PKGBUILD .SRCINFO
git -C "$aur" -c user.name="github-actions[bot]" -c user.email="41898282+github-actions[bot]@users.noreply.github.com" \
  commit -qm "Update to $version-$pkgrel"
git -C "$aur" push -q origin HEAD:master
echo "Published promethee $version-$pkgrel to the AUR"
