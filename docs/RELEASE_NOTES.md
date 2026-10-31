## Extra Dim v3.3: fix for ROMs whose display driver ignores colour transforms

**What's new**
- **`extradim gpu on`**: on some ROMs SurfaceFlinger holds the dim but the panel doesn't change (Android's own Extra Dim, Night Light and reading mode fail too). This forces GPU composition while dimmed so the dim is applied in software. Try it first with `su -c 'extradim test gpu'`. It costs some battery while dimmed and is off by default.
- `su -c 'extradim diag probe'` now also shows the GPU state, HWC capability lines and the backlight nodes.
- Still: no root grant needed (idle listener), Android 8 → 17+, two engines picked automatically.

**Install:** Magisk / KernelSU / APatch → Modules → Install from storage → reboot.
Verified on Android 11 (Magisk). The no-grant path is confirmed on KernelSU-family ksud 4.2 / Android 16; reports welcome (paste `extradim diag probe`).

Made with ❤️ by t.me/Shivraj_editx
