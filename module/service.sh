#!/system/bin/sh
# Boot tasks. Runs once and leaves ONE idle listener behind (inotifyd, or a blocking pipe reader on
# ROMs without inotifyd): no polling, no wakeups until you tap the tile.
# Made with ❤️ by t.me/Shivraj_editx
MODDIR=${0%/*}
DATA=${EXTRADIM_DATA:-/data/adb/extradim}
PKG=com.extradim.tile
TILE=$PKG/$PKG.DimTileService
DEDIR=${EXTRADIM_DEDIR:-/data/user_de/0/$PKG/files}

mkdir -p "$DATA" 2>/dev/null
: > "$DATA/boot.log"
log() { echo "$(date +%H:%M:%S) $*" >> "$DATA/boot.log"; }
log "service.sh start (uid $(id -u), sdk $(getprop ro.build.version.sdk))"

until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 3; done
sleep 8
log "boot completed"

# 1) restore the dim only if "keep on after restart" is enabled; otherwise make sure all is normal
sh "$MODDIR/system/bin/extradim" boot

# 2) wait until the package manager knows the tile app (it is a system app, so this is quick)
i=0
until pm path "$PKG" >/dev/null 2>&1 || [ "$i" -ge 20 ]; do sleep 3; i=$((i + 1)); done

# inotifyd lives in toybox on some ROMs and in the root manager's busybox on others
find_inotifyd() {
  for c in "inotifyd" "toybox inotifyd" "/system/bin/toybox inotifyd" "/data/adb/ksu/bin/busybox inotifyd" \
           "/data/adb/ap/bin/busybox inotifyd" "/data/adb/magisk/busybox inotifyd" "busybox inotifyd"; do
    bin=${c%% *}
    if ! command -v "$bin" >/dev/null 2>&1 && [ ! -x "$bin" ]; then continue; fi
    out=$($c 2>&1 </dev/null | head -n 3)
    case "$out" in
      ''|*"not found"*|*"Unknown command"*|*"unknown command"*|*"applet not"*) continue ;;
    esac
    echo "$c"
    return 0
  done
  return 1
}

start_listener() {
  [ -n "$APPUID" ] || { log "listener: app uid unknown, skipped"; return 0; }
  [ -f "$DATA/no-listener" ] && { log "listener: disabled by $DATA/no-listener"; return 0; }
  if [ ! -d "$DEDIR" ]; then
    mkdir -p "$DEDIR" && chown "$APPUID:$APPUID" "$DEDIR" && chmod 770 "$DEDIR"
    log "listener: created $DEDIR"
  fi
  rm -f "$DEDIR/cmd" "$DEDIR/.listener" "$DEDIR/cmd.fifo"
  restorecon -R "$DEDIR" >/dev/null 2>&1

  KIND=""
  INO=$(find_inotifyd)
  if [ -n "$INO" ]; then
    nohup $INO "$MODDIR/cmd-handler.sh" "$DEDIR:w" >/dev/null 2>&1 &
    LPID=$!
    sleep 1
    if kill -0 "$LPID" 2>/dev/null; then KIND=inotify; else log "listener: '$INO' exited at once"; fi
  else
    log "listener: no inotifyd on this ROM"
  fi
  if [ -z "$KIND" ]; then
    if mkfifo "$DEDIR/cmd.fifo" 2>/dev/null; then
      chown "$APPUID:$APPUID" "$DEDIR/cmd.fifo" 2>/dev/null
      chmod 660 "$DEDIR/cmd.fifo"
      restorecon "$DEDIR/cmd.fifo" >/dev/null 2>&1
      nohup sh "$MODDIR/fifo-loop.sh" "$DEDIR" >/dev/null 2>&1 &
      LPID=$!
      sleep 1
      if kill -0 "$LPID" 2>/dev/null; then KIND=fifo; else log "listener: pipe reader exited at once"; rm -f "$DEDIR/cmd.fifo"; fi
    else
      log "listener: mkfifo failed"
    fi
  fi
  if [ -n "$KIND" ]; then
    echo "$KIND" > "$DEDIR/.listener"
    chown "$APPUID:$APPUID" "$DEDIR/.listener" 2>/dev/null
    restorecon "$DEDIR/.listener" >/dev/null 2>&1
    log "listener: running (kind=$KIND, pid $LPID)"
  else
    log "listener: none - the app falls back to su (needs a root grant)"
  fi
}

APPUID=""
if pm path "$PKG" >/dev/null 2>&1; then
  APPUID=$(stat -c %u "/data/data/$PKG" 2>/dev/null)
  case "$APPUID" in
    ''|*[!0-9]*)
      APPUID=$(cmd package list packages -U "$PKG" 2>/dev/null | sed -n 's/.*uid:\([0-9][0-9]*\).*/\1/p' | head -n 1) ;;
  esac
  case "$APPUID" in ''|*[!0-9]*) APPUID="" ;; esac
  log "tile app: installed, uid ${APPUID:-unknown}"

  # 3) Magisk only: give the tile app root once. A choice already made in the app is never touched.
  #    (KernelSU and APatch have no command for this, which is what step 4 is for.)
  if [ -n "$APPUID" ] && command -v magisk >/dev/null 2>&1; then
    have=$(magisk --sqlite "SELECT policy FROM policies WHERE uid=$APPUID" 2>/dev/null)
    if [ -z "$have" ]; then
      magisk --sqlite "REPLACE INTO policies (uid,policy,until,logging,notification) VALUES($APPUID,2,0,0,0)" >/dev/null 2>&1
      log "magisk: root granted to the tile app"
    else
      log "magisk: tile app already has an entry ($have), left alone"
    fi
  fi

  # 4) Every manager (Magisk, KernelSU, APatch): an idle listener on the app's own private folder.
  #    The app drops a one-line command there, cmd-handler.sh runs it as root, so nothing has to be
  #    granted or unhidden. Opt out with:  touch /data/adb/extradim/no-listener
  start_listener
else
  log "tile app: not installed (pm path failed)"
fi

# 5) first boot only: put the tile into Quick Settings (so removing it later sticks)
if [ ! -f "$DATA/tile_added" ] && pm path "$PKG" >/dev/null 2>&1; then
  case "$(settings get secure sysui_qs_tiles 2>/dev/null)" in
    *"$PKG"*) touch "$DATA/tile_added"; log "tile: already in Quick Settings" ;;
    *) cmd statusbar add-tile "$TILE" >/dev/null 2>&1 && { touch "$DATA/tile_added"; log "tile: added to Quick Settings"; } ;;
  esac
fi

# 6) the colour pipeline can be re-initialised late in boot; one more nudge
sleep 20
sh "$MODDIR/system/bin/extradim" reapply
log "done"
