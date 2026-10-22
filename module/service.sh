#!/system/bin/sh
# Boot tasks. Runs once, then exits - no loops, no wakelocks.
MODDIR=${0%/*}
DATA=${EXTRADIM_DATA:-/data/adb/extradim}
PKG=com.extradim.tile
TILE=$PKG/$PKG.DimTileService

until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 3; done
sleep 8

# 1) restore the dim only if "keep on after restart" is enabled; otherwise make sure all is normal
sh "$MODDIR/system/bin/extradim" boot

# 2) first boot only: put the tile into Quick Settings (so removing it later sticks)
mkdir -p "$DATA" 2>/dev/null
if [ ! -f "$DATA/tile_added" ]; then
  i=0
  until pm path "$PKG" >/dev/null 2>&1 || [ "$i" -ge 20 ]; do sleep 3; i=$((i + 1)); done
  if pm path "$PKG" >/dev/null 2>&1; then
    case "$(settings get secure sysui_qs_tiles 2>/dev/null)" in
      *"$PKG"*) touch "$DATA/tile_added" ;;
      *) cmd statusbar add-tile "$TILE" >/dev/null 2>&1 && touch "$DATA/tile_added" ;;
    esac
  fi
fi

# 3) the colour pipeline can be re-initialised late in boot; one more nudge
sleep 20
sh "$MODDIR/system/bin/extradim" reapply
