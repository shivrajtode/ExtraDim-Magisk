Extra Dim (Android 8 - 17+)  -  Magisk / KernelSU / APatch module
Made with ❤️ by t.me/Shivraj_editx

Flash it, reboot. The "Extra dim" tile is added to Quick Settings on first boot
(long-press it for intensity + "keep on after restart"). No root grant needed.

  su -c 'extradim test'     dims for 3 seconds, then restores
  su -c 'extradim check'    battery check: is the dim done by the display controller?
  su -c 'extradim status'   engine / state
  su -c 'extradim help'     all commands

Opt out of the idle listener: touch /data/adb/extradim/no-listener  (then reboot)

Full docs, source and releases: https://github.com/shivrajtode/ExtraDim-Magisk
