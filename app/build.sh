#!/data/data/com.termux/files/usr/bin/sh
# Builds + signs + installs the Extra dim QS tile app entirely inside Termux (no PC).
# Made with ❤️ by t.me/Shivraj_editx
#
#   sh build.sh                 build, sign, install (needs root for the install step)
#   sh build.sh --no-install    only produce ~/ExtraDimTile.apk
#
# Two different things are needed and they come from different files:
#   classes   (javac / d8)    -> an android.jar with classes  (Termux `ecj` package ships one)
#   resources (aapt2 / aapt)  -> a resource table: /system/framework/framework-res.apk of this
#                                device works; an SDK android.jar is downloaded only as a last resort.

cd "$(dirname "$0")" || exit 1
OUT=build
PREFIX=${PREFIX:-/data/data/com.termux/files/usr}
# Google's official SDK platform package; only android-35/android.jar is taken out of it.
SDK_URL="https://dl.google.com/android/repository/platform-35_r01.zip"
FRES=${FRAMEWORK_RES:-/system/framework/framework-res.apk}

need() { command -v "$1" >/dev/null 2>&1; }
fail() { echo "!! $*" >&2; exit 1; }
inst() { pkg install -y "$@" >/dev/null 2>&1 || true; }

echo "[1/6] checking tools"
need unzip || inst unzip
need keytool || inst openjdk-17                 # javac + keytool
need aapt2 || need aapt || inst aapt2
need aapt2 || need aapt || inst aapt
need javac || need ecj || inst ecj
need d8 || need dx || inst dx
need d8 || need dx || inst d8
need apksigner || inst apksigner
need zip || inst zip
need unzip || fail "unzip missing (pkg install unzip)"
need zip || fail "zip missing (pkg install zip)"
need apksigner || fail "apksigner missing (pkg install apksigner)"
need keytool || fail "keytool missing (pkg install openjdk-17)"
need aapt2 || need aapt || fail "need aapt2 or aapt (pkg install aapt2)"
need javac || need ecj || fail "need javac or ecj (pkg install openjdk-17)"
need d8 || need dx || fail "need d8 or dx (pkg install dx)"

has_classes() { [ -f "$1" ] && unzip -l "$1" android/service/quicksettings/TileService.class >/dev/null 2>&1; }
has_res()     { [ -f "$1" ] && unzip -l "$1" resources.arsc >/dev/null 2>&1; }

fetch_sdk_jar() {
  [ -f "$HOME/.android/android.jar" ] && has_res "$HOME/.android/android.jar" && return 0
  echo "    downloading android.jar from Google's SDK repository (~65 MB, one time)"
  mkdir -p "$HOME/.android"
  Z="$HOME/.android/platform-35_r01.zip"
  if need curl; then curl -fL -o "$Z" "$SDK_URL"
  elif need wget; then wget -O "$Z" "$SDK_URL"
  else inst curl; curl -fL -o "$Z" "$SDK_URL"; fi
  unzip -j -o "$Z" "android-35/android.jar" -d "$HOME/.android" >/dev/null 2>&1
  rm -f "$Z"
  [ -f "$HOME/.android/android.jar" ]
}

find_cjar() {
  for c in "$ANDROID_JAR" "$HOME/.android/android.jar" "$HOME/android.jar" \
           "$PREFIX/share/java/android.jar"; do
    if [ -n "$c" ] && has_classes "$c"; then echo "$c"; return 0; fi
  done
  for c in $(find "$PREFIX" "$HOME" -name 'android*.jar' -size +1000k 2>/dev/null); do
    if has_classes "$c"; then echo "$c"; return 0; fi
  done
  return 1
}

CJAR=$(find_cjar)
if [ -z "$CJAR" ]; then
  echo "    no android.jar with classes yet -> trying: pkg install ecj"
  inst ecj
  CJAR=$(find_cjar)
fi
if [ -z "$CJAR" ]; then
  fetch_sdk_jar
  CJAR=$(find_cjar)
fi
[ -n "$CJAR" ] || fail "no android.jar with classes. Get platform-35_r01.zip from dl.google.com/android/repository/, unzip android-35/android.jar to ~/.android/android.jar, re-run."
echo "    classes  : $CJAR"

rm -rf "$OUT"
mkdir -p "$OUT/classes" "$OUT/dex"

echo "[2/6] manifest + resources"
: > "$OUT/res.log"
build_res() {   # $1 = resource table; produces $OUT/base.apk
  rm -f "$OUT/base.apk" "$OUT/res.zip"
  if need aapt2 \
     && aapt2 compile --dir res -o "$OUT/res.zip" >>"$OUT/res.log" 2>&1 \
     && aapt2 link -o "$OUT/base.apk" -I "$1" --manifest AndroidManifest.xml \
          --min-sdk-version 24 --target-sdk-version 29 "$OUT/res.zip" >>"$OUT/res.log" 2>&1; then
    return 0
  fi
  if need aapt \
     && aapt package -f -M AndroidManifest.xml -S res -I "$1" -F "$OUT/base.apk" \
          --min-sdk-version 24 --target-sdk-version 29 >>"$OUT/res.log" 2>&1; then
    return 0
  fi
  return 1
}
RJAR=""
try_res() {
  for r in "$@"; do
    if has_res "$r"; then
      echo "    trying resource table: $r"
      if build_res "$r"; then RJAR=$r; return 0; fi
    fi
  done
  return 1
}
try_res "$ANDROID_JAR" "$PREFIX/share/aapt/android.jar" "$HOME/.android/android.jar" \
        "$HOME/.android/framework-res.apk" "$FRES" \
  || { echo "    no local resource table worked -> SDK android.jar"; fetch_sdk_jar; try_res "$HOME/.android/android.jar"; } \
  || { tail -n 20 "$OUT/res.log"; fail "resource linking failed (full log: $PWD/$OUT/res.log)"; }
echo "    resources: $RJAR"

echo "[3/6] compiling java"
SRC=$(find src -name '*.java')
if need javac; then
  javac -encoding UTF-8 -source 8 -target 8 -Xlint:-options -bootclasspath "$CJAR" \
    -d "$OUT/classes" $SRC || fail "javac failed"
else
  # Termux's ecj wrapper already passes -7; adding -source/-target makes it error out.
  ecj -encoding UTF-8 -bootclasspath "$CJAR" -d "$OUT/classes" $SRC || fail "ecj failed"
fi

echo "[4/6] dex"
if need d8; then
  d8 --lib "$CJAR" --min-api 24 --output "$OUT/dex" $(find "$OUT/classes" -name '*.class') \
    || fail "d8 failed"
else
  dx --dex --output="$OUT/dex/classes.dex" "$OUT/classes" || fail "dx failed"
fi
[ -f "$OUT/dex/classes.dex" ] || fail "classes.dex was not produced"

echo "[5/6] package + sign"
cp "$OUT/base.apk" "$OUT/unsigned.apk"
( cd "$OUT/dex" && zip -q -j ../unsigned.apk classes.dex ) || fail "zip failed"
KS="$HOME/.android/debug.keystore"
if [ ! -f "$KS" ]; then
  mkdir -p "$HOME/.android"
  keytool -genkeypair -keystore "$KS" -alias androiddebugkey -keyalg RSA -keysize 2048 \
    -validity 10000 -storepass android -keypass android \
    -dname "CN=Extra Dim,O=Shivraj_editx,C=IN" >/dev/null 2>&1 || fail "keytool failed"
fi
apksigner sign --ks "$KS" --ks-pass pass:android --key-pass pass:android \
  --out "$OUT/ExtraDimTile.apk" "$OUT/unsigned.apk" || fail "apksigner failed"
cp "$OUT/ExtraDimTile.apk" "$HOME/ExtraDimTile.apk"
echo "    built: $HOME/ExtraDimTile.apk"

if [ "$1" = "--no-install" ]; then
  echo "done (not installed)."
  exit 0
fi

echo "[6/6] installing (grant root if asked)"
APK="$PWD/$OUT/ExtraDimTile.apk"
su -c "cp '$APK' /data/local/tmp/ExtraDimTile.apk && chmod 644 /data/local/tmp/ExtraDimTile.apk \
  && pm install -r /data/local/tmp/ExtraDimTile.apk; rm -f /data/local/tmp/ExtraDimTile.apk" \
  || fail "install failed - install $HOME/ExtraDimTile.apk manually"
# best effort: drop the tile straight into Quick Settings
su -c "cmd statusbar add-tile com.extradim.tile/com.extradim.tile.DimTileService" >/dev/null 2>&1 || true

echo
echo "Done. Pull down Quick Settings -> edit -> drag 'Extra dim' in (it may already be there)."
echo "First tap: Magisk asks for root for 'Extra dim' - grant it (set notification to None to hide the toast)."
