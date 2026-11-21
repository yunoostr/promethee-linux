#!/usr/bin/env bash
# Points the PKGBUILD in <dir> at Promethee <version>: its Electron version and every checksum.
# Runs on Arch as a non-root user (makepkg); needs curl, unzip and updpkgsums (pacman-contrib).
set -euo pipefail
dir=$1
version=${2:-$(sed -n 's/^pkgver=//p' "$dir/PKGBUILD")}
plist='Promethee.app/Contents/Frameworks/Electron Framework.framework/Versions/A/Resources/Info.plist'
zip=Promethee-$version-arm64.zip

cd "$dir"
# Kept in the PKGBUILD folder, where makepkg looks first: updpkgsums and makepkg won't fetch it again.
[ -e "$zip" ] || curl -fsSL -o "$zip" "https://github.com/promethee-io/Promethee-releases/releases/download/v$version/$zip"
electron=$(unzip -p "$zip" "$plist" | grep -A1 CFBundleVersion | sed -n 's:.*<string>\(.*\)</string>.*:\1:p')
[ -n "$electron" ] || { echo "No Electron version found in $zip" >&2; exit 1; }
sed -i -e "s/^pkgver=.*/pkgver=$version/" -e "s/^_electron=[^ ]*/_electron=$electron/" PKGBUILD
updpkgsums >/dev/null
