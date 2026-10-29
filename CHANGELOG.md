# Changelog

All notable changes to this project. Made with ❤️ by t.me/Shivraj_editx

## [v3.2] - 2026-10-28
### Added
- **Sturdier no-root path.** The boot script now searches toybox and every manager's busybox for `inotifyd`, and falls back to a blocking named-pipe listener when there is none (tile app **v1.3** pokes it). `/data/adb/extradim/boot.log` records what happened.
- `extradim diag [probe]`: one report to paste when something doesn't work. `extradim engine sf|auto`: switch engines.
- **Native engine check (Android 12+).** If the framework accepts the settings but does not activate Extra Dim, the helper switches to the SurfaceFlinger engine by itself.

## [v3.1] - 2026-10-24
### Added
- **Root is automatic.** Magisk: the boot script grants the tile app root once (never overriding your choice). **KernelSU / APatch / Magisk:** an idle `inotifyd` listener lets the tile app send commands without any root grant, so nothing has to be unhidden under *show system apps*.
- Tile app **v1.2**: sends commands through that listener, falling back to `su` when it isn't running.
- Release zip is now named `ExtraDim-<version>.zip`.

### Notes
- The one idle listener replaces the old "nothing in the background" claim. It does no polling. Opt out with `touch /data/adb/extradim/no-listener`.

## [v3.0] - 2026-10-22
### Added
- **Android 8 → 17+**: the module installs on API 26 and newer (previously Android 10/11 only).
- **Two engines**, picked automatically: the real Extra Dim settings on Android 12+ ROMs whose framework reports it as available, the SurfaceFlinger colour matrix everywhere else.
- Tile app **v1.1** reads the helper's own settings keys (`extradim_*`) first.
- `extradim status` shows engine and API; `ENGINE=sf` in the config forces the SurfaceFlinger engine.
- GitHub repo with docs, artwork, `tools/build.sh` and `tools/publish.sh`.

### Safety
- On Android 12+ the helper never writes AOSP's `reduce_bright_colors_*` keys unless `dumpsys color_display` reports the feature as available.

## [v2.0] - 2026-10-21
- Tile app bundled in the module as a systemless system app; tile added to Quick Settings on first boot.

## [v1.3] - [v1.0]
- Root helper (`extradim`) with the SurfaceFlinger matrix, `test` and `check` commands, restart-aware state (boot counter), Quick Settings tile app and a Termux build script.
