# Changelog

All notable changes to this project. Made with ❤️ by t.me/Shivraj_editx

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
