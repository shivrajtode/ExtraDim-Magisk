#!/usr/bin/env bash
# Builds dist/ExtraDim-<version>.zip from module/  (+ update.json when OWNER/REPO are known)
#
#   bash tools/build.sh          zip only (uses the tile APK already in module/)
#   bash tools/build.sh --app    rebuild the tile app from app/ first (Termux; needs the build
#                                tools - app/build.sh installs what it can). Needed once for
#                                Android 12+: the prebuilt APK is v1.0, the source is v1.1.
#
# Made with ❤️ by t.me/Shivraj_editx
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
command -v zip >/dev/null 2>&1 || { echo "zip missing (pkg install zip)" >&2; exit 1; }

if [ "${1:-}" = "--app" ]; then
  echo "▸ rebuilding the tile app from app/ ..."
  if sh app/build.sh --no-install && [ -f "$HOME/ExtraDimTile.apk" ]; then
    cp "$HOME/ExtraDimTile.apk" module/system/app/ExtraDimTile/ExtraDimTile.apk
    sed -n 's/.*android:versionCode="\([0-9][0-9]*\)".*/\1/p' app/AndroidManifest.xml | head -n 1 > module/app_version
    echo "✔ tile app rebuilt (versionCode $(cat module/app_version))"
  else
    echo "! app rebuild failed - keeping the bundled APK (versionCode $(cat module/app_version))" >&2
  fi
fi

VER=$(sed -n 's/^version=//p' module/module.prop | head -n 1)
VC=$(sed -n 's/^versionCode=//p' module/module.prop | head -n 1)
[ -n "$VER" ] && [ -n "$VC" ] || { echo "module/module.prop needs version and versionCode" >&2; exit 1; }
OUT="dist/ExtraDim-$VER.zip"

STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
cp -a module/. "$STAGE/"
# a shipped zip must not contain unfilled placeholders
if grep -q '{{' "$STAGE/module.prop"; then sed -i '/{{/d' "$STAGE/module.prop"; fi
if grep -q '{{' "$STAGE/README.txt"; then sed -i '/{{/d' "$STAGE/README.txt"; fi
chmod 755 "$STAGE/system/bin/extradim" "$STAGE/service.sh" "$STAGE/uninstall.sh" "$STAGE/customize.sh" \
  "$STAGE/META-INF/com/google/android/update-binary"

mkdir -p dist
rm -f "$ROOT/$OUT"
( cd "$STAGE" && zip -qr -X "$ROOT/$OUT" . )

if [ -n "${OWNER:-}" ] && [ -n "${REPO:-}" ]; then
  B=${BRANCH:-main}
  cat > update.json <<JSON
{
  "version": "$VER",
  "versionCode": $VC,
  "zipUrl": "https://github.com/$OWNER/$REPO/releases/download/$VER/$(basename "$OUT")",
  "changelog": "https://raw.githubusercontent.com/$OWNER/$REPO/$B/CHANGELOG.md"
}
JSON
fi
echo "✔ built $OUT ($(wc -c < "$OUT") bytes)"
