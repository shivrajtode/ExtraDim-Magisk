##########################################################################################
# Extra Dim (Android 8 - 17+)  -  Made with ❤️ by t.me/Shivraj_editx
##########################################################################################

API=${API:-$(getprop ro.build.version.sdk)}

ui_print "*********************************************"
ui_print "   Extra Dim  (Android 8 - 17+)"
ui_print "   Made with ❤️ by t.me/Shivraj_editx"
ui_print "*********************************************"

if ! [ "$API" -ge 26 ] 2>/dev/null; then
  abort "! Needs Android 8.0 or newer (API 26+), found API '$API'"
fi

APKDIR="$MODPATH/system/app/ExtraDimTile"
[ -f "$APKDIR/ExtraDimTile.apk" ] || abort "! ExtraDimTile.apk is missing from the zip"

ui_print "- Android API $API: the engine is picked at runtime (su -c 'extradim status')"
if [ "$API" -ge 38 ]; then
  ui_print "- API $API is newer than anything tested - after boot run: su -c 'extradim test'"
fi

ui_print "- Installing root helper: extradim"
ui_print "- Installing Quick Settings tile app (systemless system app)"
set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm_recursive "$APKDIR" 0 0 0755 0644 u:object_r:system_file:s0
set_perm "$MODPATH/system/bin/extradim" 0 2000 0755 u:object_r:system_file:s0
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/cmd-handler.sh" 0 0 0755
set_perm "$MODPATH/fifo-loop.sh" 0 0 0755
set_perm "$MODPATH/uninstall.sh" 0 0 0755

# Tile app v1.2+ talks to the module's idle listener (no root grant needed, any manager). Older builds
# only know "su": fine on Magisk (granted automatically), but not on KernelSU/APatch.
APPV=$(cat "$MODPATH/app_version" 2>/dev/null)
if [ "${APPV:-1}" -ge 4 ] 2>/dev/null; then
  ui_print "- Root for the tile app is automatic: Magisk gets a grant, and an idle listener"
  ui_print "  serves Magisk, KernelSU and APatch alike (nothing to unhide or grant by hand)"
else
  ui_print "- Magisk: the tile app is granted root automatically"
  ui_print "! The bundled tile app is an older build (before v1.3). KernelSU/APatch and Android 12+ ROMs"
  ui_print "  need v1.3. Rebuild it once in Termux:  bash tools/build.sh --app"
  ui_print "  (then flash the zip it puts in dist/)"
fi

# A copy you installed by hand keeps working (same package + signature); mention it once.
if [ "$BOOTMODE" = "true" ] && command -v pm >/dev/null 2>&1; then
  case "$(pm path com.extradim.tile 2>/dev/null | head -n 1)" in
    *"/data/app/"*)
      ui_print "- Found a manually installed Extra dim app: it keeps working."
      ui_print "  For a clean module-owned copy: su -c 'pm uninstall com.extradim.tile' then reboot" ;;
  esac
fi

ui_print "- Nothing in framework/SystemUI is patched; one idle listener, no polling"
ui_print "- Reboot, then the 'Extra dim' tile is added to Quick Settings (first boot only)"
ui_print "- Quick test after reboot:  su -c 'extradim test'   (if it misbehaves: su -c 'extradim diag')"
