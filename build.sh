#!/usr/bin/env bash
# Builds an unofficial Linux version of Promethee from the official macOS release.
# Nothing from Promethee is redistributed: the official build is downloaded and patched locally.
#
# Usage: ./build.sh [version]   (default: latest release)
# Needs: curl, unzip, node/npx, python3, make, g++ (13+)
set -euo pipefail

REPO=promethee-io/Promethee-releases
ROOT=$(cd "$(dirname "$0")" && pwd)
RES=Promethee.app/Contents/Resources
ELECTRON_PLIST='Promethee.app/Contents/Frameworks/Electron Framework.framework/Versions/A/Resources/Info.plist'
# Exact versions, so npx neither runs whatever is newest on npm nor a global install that may not
# support this Node (node-gyp 13 needs Node 22.22+). Both of these run on Node 20.17+ and 22.
ASAR=@electron/asar@3.4.1
NODE_GYP=node-gyp@12.4.0
# A package build (AUR) sets PROMETHEE_SOURCES to a folder of checksummed downloads (macOS zip,
# Electron zip, Electron headers) and provides asar and node-gyp: then nothing is fetched here.
SOURCES=${PROMETHEE_SOURCES:-}
if [ -n "$SOURCES" ]; then
  ASAR_CMD=(asar) GYP_CMD=(node-gyp --nodedir="$SOURCES/node_headers")
else
  ASAR_CMD=(npx -y "$ASAR") GYP_CMD=(npx -y "$NODE_GYP" --dist-url=https://electronjs.org/headers)
fi

log() { echo "==> $*"; }

# Stops the build unless a download matches its published hash: check_hash <file> <expected> <actual>.
check_hash() {
  if [ -z "$2" ] || [ "$2" != "$3" ]; then
    echo "Checksum mismatch for $1 (expected '${2:-none published}', got '$3'), stopping." >&2
    exit 1
  fi
  log "Checksum OK: $1"
}

download() {  # <file> <url>
  if [ -z "$SOURCES" ]; then curl -fL# -o "$1" "$2"; return; fi
  [ -e "$SOURCES/$1" ] || { echo "Missing $1 in $SOURCES" >&2; exit 1; }
  ln -s "$SOURCES/$1" "$1"
}

# Stops before any download when a tool is missing or g++ is too old: otherwise the build
# fails minutes in, after ~450 MB of downloads, with a node-gyp or C++ error.
check_tools() {
  local cxx=${CXX:-g++} tool missing=()
  local tools=(unzip node python3 make "$cxx")
  if [ -n "$SOURCES" ]; then tools+=(asar node-gyp); else tools+=(curl npx); fi
  for tool in "${tools[@]}"; do command -v "$tool" >/dev/null || missing+=("$tool"); done
  if [ ${#missing[@]} -gt 0 ]; then
    echo "Missing: ${missing[*]}. Install them first, see the README's Quick start." >&2
    exit 1
  fi
  # Electron 43's V8 headers don't parse with g++ 12 (Debian 12); g++ 13 (Ubuntu 24.04) works.
  local version
  version=$("$cxx" -dumpversion)
  if [ "${version%%.*}" -lt 13 ]; then
    echo "$cxx $version is too old: Electron's headers need g++ 13 or newer." >&2
    exit 1
  fi
}

# Sets VERSION: the argument, or the latest release tag (read from GitHub's redirect).
detect_version() {
  VERSION=${1:-}
  if [ -z "$VERSION" ]; then
    VERSION=$(curl -fsSo /dev/null -w '%{redirect_url}' --max-time 20 "https://github.com/$REPO/releases/latest") \
      || { echo "Can't reach GitHub to find the latest Promethee release: check your connection." >&2; exit 1; }
  fi
  VERSION=${VERSION##*/v}
  # It ends up in paths that get rm -rf'd: refuse anything but a plain version (same check as CI).
  [[ $VERSION =~ ^[0-9]+(\.[0-9]+)*$ ]] || { echo "Unexpected Promethee version: '$VERSION'" >&2; exit 1; }
}

# Sets ARCH in Electron's naming (x64 / arm64).
detect_arch() {
  case $(uname -m) in
    x86_64) ARCH=x64 ;;
    aarch64 | arm64) ARCH=arm64 ;;
    *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
  esac
}

# Fresh work and output dirs; everything below runs inside WORK.
prepare_dirs() {
  WORK=$ROOT/build/$VERSION
  OUT=$ROOT/dist/promethee-$VERSION-linux-$ARCH
  rm -rf "$WORK" "$OUT"
  mkdir -p "$WORK" "$OUT"
  cd "$WORK"
}

# Downloads the official mac build, extracts app.asar into ./app, sets ELECTRON (its version).
fetch_mac_app() {
  log "Promethee $VERSION (linux-$ARCH)"
  # ponytail: the mac arch doesn't matter, we only keep the JS and the native module sources
  local base=https://github.com/$REPO/releases/download/v$VERSION zip=Promethee-$VERSION-arm64.zip
  download "$zip" "$base/$zip"
  # electron-builder's update manifest lists the zip's sha512 (base64), hashed here with node
  # since it's already required. Same release as the zip: catches corrupt or truncated
  # downloads and tampering in transit, not a compromised release.
  # A package build has no network here, and makepkg already checked its own checksums.
  if [ -z "$SOURCES" ]; then
    curl -fsSL -o mac.yml "$base/darwin-arm64-mac.yml"
    check_hash "$zip" \
      "$(grep -A1 -F "url: $zip" mac.yml | sed -n 's/^ *sha512: *//p')" \
      "$(node -e 'const h=require("crypto").createHash("sha512");
        require("fs").createReadStream(process.argv[1]).on("data",d=>h.update(d)).on("end",()=>process.stdout.write(h.digest("base64")))' "$zip")"
  fi
  unzip -q "$zip" "$RES/app.asar" "$RES/app.asar.unpacked/*" "$RES/assets/*" "$ELECTRON_PLIST"

  ELECTRON=$(grep -A1 CFBundleVersion "$ELECTRON_PLIST" | sed -n 's:.*<string>\(.*\)</string>.*:\1:p')
  log "Electron $ELECTRON"

  log "Extracting app.asar"
  "${ASAR_CMD[@]}" extract "$RES/app.asar" app
}

# Drops macOS-only modules and recompiles SQLite for Linux.
patch_natives() {
  log "Rebuilding native modules for Linux"
  # mac-vibrancy / win-vdesktop are only required behind a platform check, safe to drop.
  rm -rf app/node_modules/mac-vibrancy

  local sqlite=app/node_modules/better-sqlite3-multiple-ciphers
  rm -rf "${sqlite:?}/bin" "${sqlite:?}/build"
  (cd "$sqlite" && "${GYP_CMD[@]}" rebuild --release \
    --runtime=electron --target="$ELECTRON" --arch="$ARCH")
  # Keep only the addon: the rest of build/ (Makefiles, config.gypi, sqlite3.a) embeds build paths.
  mv "$sqlite/build/Release/better_sqlite3.node" "$WORK/"
  rm -rf "${sqlite:?}/build" && mkdir -p "$sqlite/build/Release"
  mv "$WORK/better_sqlite3.node" "$sqlite/build/Release/"
}

# Lets active-win see native Wayland windows (Hyprland, sway): its own Linux code only asks X11.
patch_window_detection() {
  local lib=app/node_modules/active-win/lib
  [ -f "$lib/linux.js" ] || { log "active-win not found, window detection left as is"; return; }
  mv "$lib/linux.js" "$lib/x11.js"
  cp "$ROOT/patches/active-win-linux.js" "$lib/linux.js"
}

# Downloads the official Linux Electron of the same version into OUT.
fetch_electron() {
  log "Downloading Electron $ELECTRON"
  local base=https://github.com/electron/electron/releases/download/v$ELECTRON zip=electron-v$ELECTRON-linux-$ARCH.zip
  download "$zip" "$base/$zip"
  if [ -z "$SOURCES" ]; then
    curl -fsSL -o SHASUMS256.txt "$base/SHASUMS256.txt"   # lines: "<sha256> *<file>"
    check_hash "$zip" \
      "$(awk -v f="*$zip" '$2 == f { print $1 }' SHASUMS256.txt)" \
      "$(sha256sum "$zip" | cut -d' ' -f1)"
  fi
  unzip -q "$zip" -d "$OUT"
}

# Puts the patched app inside Electron and writes the launcher.
assemble() {
  # Binary must not be named "electron", otherwise app.isPackaged is false (dev mode).
  mv "$OUT/electron" "$OUT/promethee-bin"
  rm -f "$OUT/resources/default_app.asar"
  mv app "$OUT/resources/app"
  mv "$RES/assets" "$OUT/resources/assets"

  # active-win (window detection) is only used as a fallback behind this flag on non-mac/win.
  cat > "$OUT/promethee" <<'EOF'
#!/usr/bin/env bash
export PROMETHEE_ENABLE_PERMISSION_TRACKING=1
exec "$(dirname "$(readlink -f "$0")")/promethee-bin" "$@"
EOF
  chmod +x "$OUT/promethee"
  echo "$VERSION" > "$OUT/VERSION"
}

# Points dist/current at this build (what ./promethee launches) and drops the downloads.
activate() {
  ln -sfn "$(basename "$OUT")" "$ROOT/dist/current"
  rm -rf "$WORK"
}

main() {
  check_tools
  detect_version "$@"
  detect_arch
  prepare_dirs
  fetch_mac_app
  patch_natives
  patch_window_detection
  fetch_electron
  assemble
  activate

  echo
  echo "Done: Promethee $VERSION is ready. Start it with ./promethee"
}

main "$@"
