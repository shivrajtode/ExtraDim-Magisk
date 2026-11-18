#!/system/bin/sh
# Called by inotifyd whenever the panel backlight node is written:  bl-handler.sh EVENTS FILE
# (backlight engine only) Re-applies the dim to whatever the system just wrote.
# Made with ❤️ by t.me/Shivraj_editx
DATA=${EXTRADIM_DATA:-/data/adb/extradim}
[ -f "$DATA/bl_active" ] || exit 0
cur=$(cat "$2" 2>/dev/null)
case "$cur" in ''|*[!0-9]*) exit 0 ;; esac
[ "$cur" = "$(cat "$DATA/bl_last" 2>/dev/null)" ] && exit 0     # that was our own write
L=$(cat "$DATA/bl_factor" 2>/dev/null)
case "$L" in ''|*[!0-9]*) exit 0 ;; esac
echo "$cur" > "$DATA/bl_sys"                                    # what the system wants
if [ "$cur" -gt 0 ]; then s=$(( cur * L / 1000 )); [ "$s" -lt 1 ] && s=1; else s=0; fi
echo "$s" > "$DATA/bl_last"                                     # remember before writing: the write fires this handler again
echo "$s" > "$2"
exit 0
