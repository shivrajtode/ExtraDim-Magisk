#!/system/bin/sh
# Fallback listener for ROMs without inotifyd: blocks (no polling, no CPU) on a named pipe in the
# tile app's private folder. The app writes its command to <dir>/cmd and pokes the pipe.
#   fifo-loop.sh <dir>
# Made with ❤️ by t.me/Shivraj_editx
MODDIR=${0%/*}
DIR=$1
FIFO="$DIR/cmd.fifo"
[ -p "$FIFO" ] || exit 1
exec 3<>"$FIFO"            # read+write: never sees EOF, and the app's non-blocking open always works
while read -r _ <&3; do
  [ -p "$FIFO" ] || exit 0  # pipe removed (module disabled/uninstalled): stop quietly
  sh "$MODDIR/cmd-handler.sh" w "$DIR" cmd
done
exit 0
