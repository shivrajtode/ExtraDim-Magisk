## Extra Dim v3.2: sturdier no-root path + diagnostics

**What's new**
- **The tile works without a root grant on more ROMs.** If the ROM has no `inotifyd` (or the manager's busybox lacks it), the module now falls back to a blocking named-pipe listener. Tile app **v1.3** talks to either. `/data/adb/extradim/boot.log` says what the boot script did.
- **Android 12+:** if the ROM's own Extra Dim accepts the settings but doesn't activate, the helper switches to the SurfaceFlinger engine automatically.
- `su -c 'extradim diag probe'` prints one report to paste when something doesn't dim. `su -c 'extradim engine sf'` forces the SurfaceFlinger engine.

**Install:** Magisk / KernelSU / APatch → Modules → Install from storage → reboot.
Verified on Android 11 with Magisk. Other versions and managers are expected to work; reports welcome (paste `extradim diag probe`).

Made with ❤️ by t.me/Shivraj_editx
