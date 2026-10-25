## Extra Dim v3.1: root is automatic

**What's new**
- **No root grant to fiddle with.** Magisk grants the tile app root itself. On **KernelSU and APatch**, where system apps are hidden in the root list and modules can't grant root, the tile talks to a tiny idle listener the module starts, so you don't have to enable *show system apps* or allow anything.
- Tile app **v1.2** (falls back to `su` if the listener isn't running).
- Still **Android 8 → 17+**, two engines picked automatically (native Extra Dim on Android 12+ ROMs that really have it, SurfaceFlinger matrix everywhere else).

**Install:** Magisk / KernelSU / APatch → Modules → Install from storage → reboot. The *Extra dim* tile is added to Quick Settings on first boot.
**Check:** `su -c 'extradim test'` (3-second dim) and `su -c 'extradim check'` (battery check).

One idle `inotifyd` listener stays running (no polling). Opt out: `touch /data/adb/extradim/no-listener`.
Verified on Android 11 with Magisk. KernelSU/APatch and other Android versions are expected to work; reports welcome.

Made with ❤️ by t.me/Shivraj_editx
