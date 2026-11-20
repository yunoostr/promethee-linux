#!/usr/bin/env bash
# Builds an unofficial Linux version of Promethee from the official macOS release.
# Nothing from Promethee is redistributed: the official build is downloaded and patched locally.
#
# Usage: ./build.sh [version]   (default: latest release)
# Needs: curl, unzip, node/npx, python3, make, g++ (14+)
set -euo pipefail

REPO=promethee-io/Promethee-releases
ROOT=$(cd "$(dirname "$0")" && pwd)
RES=Promethee.app/Contents/Resources
ELECTRON_PLIST='Promethee.app/Contents/Frameworks/Electron Framework.framework/Versions/A/Resources/Info.plist'
# Exact versions, so npx neither runs whatever is newest on npm nor a global install that may not
# support this Node (node-gyp 13 needs Node 22.22+). Both of these run on Node 20.17+ and 22.
ASAR=@electron/asar@3.4.1
NODE_GYP=node-gyp@12.4.0

log() { echo "==> $*"; }

# Stops the build unless a download matches its published hash: check_hash <file> <expected> <actual>.
check_hash() {
  if [ -z "$2" ] || [ "$2" != "$3" ]; then
    echo "Checksum mismatch for $1 (expected '${2:-none published}', got '$3'), stopping." >&2
    exit 1
  fi
  log "Checksum OK: $1"
}

# Sets VERSION: the argument, or the latest release tag (read from GitHub's redirect).
detect_version() {
  VERSION=${1:-$(curl -fsSo /dev/null -w '%{redirect_url}' "https://github.com/$REPO/releases/latest")}
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
  curl -fL# -o mac.zip "$base/$zip"
  # electron-builder's update manifest lists the zip's sha512 (base64), hashed here with node
  # since it's already required. Same release as the zip: catches corrupt or truncated
  # downloads and tampering in transit, not a compromised release.
  curl -fsSL -o mac.yml "$base/darwin-arm64-mac.yml"
  check_hash "$zip" \
    "$(grep -A1 -F "url: $zip" mac.yml | sed -n 's/^ *sha512: *//p')" \
    "$(node -e 'const h=require("crypto").createHash("sha512");
      require("fs").createReadStream(process.argv[1]).on("data",d=>h.update(d)).on("end",()=>process.stdout.write(h.digest("base64")))' mac.zip)"
  unzip -q mac.zip "$RES/app.asar" "$RES/app.asar.unpacked/*" "$RES/assets/*" "$ELECTRON_PLIST"

  ELECTRON=$(grep -A1 CFBundleVersion "$ELECTRON_PLIST" | sed -n 's:.*<string>\(.*\)</string>.*:\1:p')
  log "Electron $ELECTRON"

  log "Extracting app.asar"
  npx -y "$ASAR" extract "$RES/app.asar" app
}

# Drops macOS-only modules and recompiles SQLite for Linux.
patch_natives() {
  log "Rebuilding native modules for Linux"
  # mac-vibrancy / win-vdesktop are only required behind a platform check, safe to drop.
  rm -rf app/node_modules/mac-vibrancy

  local sqlite=app/node_modules/better-sqlite3-multiple-ciphers
  rm -rf "${sqlite:?}/bin" "${sqlite:?}/build"
  (cd "$sqlite" && npx -y "$NODE_GYP" rebuild --release \
    --runtime=electron --target="$ELECTRON" --arch="$ARCH" --dist-url=https://electronjs.org/headers)
  rm -rf "$sqlite/build/Release/obj" "$sqlite/build/Release/obj.target" "$sqlite/build/Release/.deps"
}

# Downloads the official Linux Electron of the same version into OUT.
fetch_electron() {
  log "Downloading Electron $ELECTRON"
  local base=https://github.com/electron/electron/releases/download/v$ELECTRON zip=electron-v$ELECTRON-linux-$ARCH.zip
  curl -fL# -o electron.zip "$base/$zip"
  curl -fsSL -o SHASUMS256.txt "$base/SHASUMS256.txt"   # lines: "<sha256> *<file>"
  check_hash "$zip" \
    "$(awk -v f="*$zip" '$2 == f { print $1 }' SHASUMS256.txt)" \
    "$(sha256sum electron.zip | cut -d' ' -f1)"
  unzip -q electron.zip -d "$OUT"
}

# Puts the patched app inside Electron and writes the launcher.
assemble() {
  # Binary must not be named "electron", otherwise app.isPackaged is false (dev mode).
  mv "$OUT/electron" "$OUT/promethee-bin"
  rm -f "$OUT/resources/default_app.asar"
  mv app "$OUT/resources/app"
  mv "$RES/assets" "$OUT/resources/assets"

  # active-win (X11 window detection) is only used as a fallback behind this flag on non-mac/win.
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
  detect_version "$@"
  detect_arch
  prepare_dirs
  fetch_mac_app
  patch_natives
  fetch_electron
  assemble
  activate

  echo
  echo "Done: Promethee $VERSION is ready. Start it with ./promethee"
}

main "$@"
