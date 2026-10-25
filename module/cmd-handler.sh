#!/system/bin/sh
# Called by inotifyd as:  cmd-handler.sh EVENTS DIR [FILE]
# Runs ONE whitelisted Extra Dim command that the tile app dropped into its own private folder
# (only that app can write there), then deletes the file so the app knows it is finished.
# Made with ❤️ by t.me/Shivraj_editx
MODDIR=${0%/*}
DIR=$2
[ "$3" = "cmd" ] || exit 0
[ -f "$DIR/cmd" ] || exit 0

line=$(head -n 1 "$DIR/cmd" 2>/dev/null | tr -d '\r')
ok=0
case "$line" in
  toggle|off|on) ok=1 ;;
  "on "*|"level "*)
    a=${line#* }
    case "$a" in ''|*[!0-9]*) ;; *) ok=1 ;; esac ;;
  "persist 0"|"persist 1") ok=1 ;;
esac
if [ "$ok" = 1 ]; then
  sh "$MODDIR/system/bin/extradim" $line >/dev/null 2>&1   # only known words and digits get here
fi
rm -f "$DIR/cmd"
exit 0
