## Extra Dim v3.0: Android 8 → 17+

**What's new**
- Works on **Android 8 – 17+** (was Android 10/11 only).
- **Two engines, picked automatically:** Android 12+ ROMs that really have Extra Dim get the native one; everything else gets the SurfaceFlinger colour-matrix engine.
- Tile app **v1.1**: reads the helper's own settings keys, so the tile shows the right state on every version.
- Safer on Android 12+: AOSP's `reduce_bright_colors_*` settings are never written unless the framework reports the feature as available.

**Install:** Magisk → Modules → Install from storage → reboot. The *Extra dim* tile is added to Quick Settings on first boot.
**Check:** `su -c 'extradim test'` (3-second dim) and `su -c 'extradim check'` (battery check).

Verified on Android 11. Other versions are covered by automated simulation; reports welcome.

Made with ❤️ by t.me/Shivraj_editx
