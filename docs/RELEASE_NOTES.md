## Extra Dim v3.4: backlight engine for panels that ignore colour transforms

**What's new**
- **`extradim engine backlight`** (experimental, opt-in): on some ROMs SurfaceFlinger holds the dim but the display driver ignores it (Android's own Extra Dim, Night Light and reading mode fail too), and GPU composition can't help on Qualcomm drivers. This lowers the panel backlight instead, and a small watcher keeps it lowered when the system rewrites the brightness. Try it first with `su -c 'extradim test backlight'`.
- `extradim gpu on` and `extradim test gpu` (v3.3) stay, for drivers where GPU composition does help.
- Still: no root grant needed (idle listener), Android 8 → 17+, two colour engines picked automatically.

**Install:** Magisk / KernelSU / APatch → Modules → Install from storage → reboot.
Verified on Android 11 (Magisk); the no-grant path is confirmed on KernelSU-family ksud 4.2 / Android 16. Reports welcome (paste `extradim diag probe`).

Made with ❤️ by t.me/Shivraj_editx
