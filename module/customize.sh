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
set_perm "$MODPATH/uninstall.sh" 0 0 0755

# Tile app v1.0 only knows AOSP's key names: fine on Android 8-11, but on Android 12+ ROMs without
# the native feature it can show the wrong state until the app is rebuilt once (see README).
APPV=$(cat "$MODPATH/app_version" 2>/dev/null)
if [ "$API" -ge 31 ] && [ "${APPV:-1}" -lt 2 ] 2>/dev/null; then
  ui_print "! Bundled tile app is v1.0: on Android 12+ run once in Termux:  bash tools/build.sh --app"
  ui_print "  (repo: README -> 'Android 12+'), then re-flash the zip it creates in dist/"
fi

# A copy you installed by hand keeps working (same package + signature); mention it once.
if [ "$BOOTMODE" = "true" ] && command -v pm >/dev/null 2>&1; then
  case "$(pm path com.extradim.tile 2>/dev/null | head -n 1)" in
    *"/data/app/"*)
      ui_print "- Found a manually installed Extra dim app: it keeps working."
      ui_print "  For a clean module-owned copy: su -c 'pm uninstall com.extradim.tile' then reboot" ;;
  esac
fi

ui_print "- Nothing in framework/SystemUI is patched, nothing runs in the background"
ui_print "- Reboot, then the 'Extra dim' tile is added to Quick Settings (first boot only)"
ui_print "- Quick test after reboot:  su -c 'extradim test'"
