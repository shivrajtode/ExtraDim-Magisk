#!/system/bin/sh
# Boot tasks. Runs once and leaves ONE idle listener (inotifyd) behind: no polling, no wakeups
# until you tap the tile. Made with ❤️ by t.me/Shivraj_editx
MODDIR=${0%/*}
DATA=${EXTRADIM_DATA:-/data/adb/extradim}
PKG=com.extradim.tile
TILE=$PKG/$PKG.DimTileService
DEDIR=${EXTRADIM_DEDIR:-/data/user_de/0/$PKG/files}

until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 3; done
sleep 8

# 1) restore the dim only if "keep on after restart" is enabled; otherwise make sure all is normal
sh "$MODDIR/system/bin/extradim" boot

mkdir -p "$DATA" 2>/dev/null

# 2) wait until the package manager knows the tile app (it is a system app, so this is quick)
i=0
until pm path "$PKG" >/dev/null 2>&1 || [ "$i" -ge 20 ]; do sleep 3; i=$((i + 1)); done

if pm path "$PKG" >/dev/null 2>&1; then
  APPUID=$(stat -c %u "/data/data/$PKG" 2>/dev/null)
  case "$APPUID" in
    ''|*[!0-9]*)
      APPUID=$(cmd package list packages -U "$PKG" 2>/dev/null | sed -n 's/.*uid:\([0-9][0-9]*\).*/\1/p' | head -n 1) ;;
  esac
  case "$APPUID" in ''|*[!0-9]*) APPUID="" ;; esac

  # 3) Magisk only: give the tile app root once. A choice already made in the app is never touched.
  #    (KernelSU and APatch have no command for this, which is what step 4 is for.)
  if [ -n "$APPUID" ] && command -v magisk >/dev/null 2>&1; then
    have=$(magisk --sqlite "SELECT policy FROM policies WHERE uid=$APPUID" 2>/dev/null)
    if [ -z "$have" ]; then
      magisk --sqlite "REPLACE INTO policies (uid,policy,until,logging,notification) VALUES($APPUID,2,0,0,0)" >/dev/null 2>&1
    fi
  fi

  # 4) Every manager (Magisk, KernelSU, APatch): an idle listener on the app's own private folder.
  #    The app drops a one-line command there, cmd-handler.sh runs it as root, so nothing has to be
  #    granted or unhidden. Opt out with:  touch /data/adb/extradim/no-listener
  if [ -n "$APPUID" ] && [ ! -f "$DATA/no-listener" ] && command -v inotifyd >/dev/null 2>&1; then
    if [ ! -d "$DEDIR" ]; then
      mkdir -p "$DEDIR" && chown "$APPUID:$APPUID" "$DEDIR" && chmod 770 "$DEDIR"
    fi
    rm -f "$DEDIR/cmd" "$DEDIR/.listener"
    restorecon -R "$DEDIR" >/dev/null 2>&1
    nohup inotifyd "$MODDIR/cmd-handler.sh" "$DEDIR:w" >/dev/null 2>&1 &
    LPID=$!
    sleep 1
    if kill -0 "$LPID" 2>/dev/null; then
      touch "$DEDIR/.listener" && chown "$APPUID:$APPUID" "$DEDIR/.listener" 2>/dev/null
      restorecon "$DEDIR/.listener" >/dev/null 2>&1
    fi
  fi
fi

# 5) first boot only: put the tile into Quick Settings (so removing it later sticks)
if [ ! -f "$DATA/tile_added" ] && pm path "$PKG" >/dev/null 2>&1; then
  case "$(settings get secure sysui_qs_tiles 2>/dev/null)" in
    *"$PKG"*) touch "$DATA/tile_added" ;;
    *) cmd statusbar add-tile "$TILE" >/dev/null 2>&1 && touch "$DATA/tile_added" ;;
  esac
fi

# 6) the colour pipeline can be re-initialised late in boot; one more nudge
sleep 20
sh "$MODDIR/system/bin/extradim" reapply
