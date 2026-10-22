# How Extra Dim works, and how this module gets it onto ROMs without it

> Made with ❤️ by t.me/Shivraj_editx

## 1. Extra Dim in AOSP (Android 12+)

Extra Dim ("Reduce Bright Colors") is a stack of layers:

| Layer | What it does |
|---|---|
| **Settings** (secure) | `reduce_bright_colors_activated`, `reduce_bright_colors_level`, `reduce_bright_colors_persist_across_reboots` |
| **Framework API** | Hidden `ColorDisplayManager` methods: set/is *ReduceBrightColorsActivated*, set/get *ReduceBrightColorsStrength* (0–100, 100 = full strength) |
| **system_server** | `ColorDisplayService` turns the strength into a per-channel scale. `DisplayTransformManager` composes every colour matrix (Extra Dim is one level of them) and sends the result to SurfaceFlinger with binder transaction **1015** |
| **Availability gate** | `config_reduceBrightColorsAvailable` follows `config_setColorTransformAccelerated`: meant to be on only when the HWC can apply the matrix without hurting power, performance or protected content |
| **UI** | A SystemUI Quick Settings tile (registered in the tile factory and tile lists), the *Extra dim* page in Settings → Accessibility, and an accessibility shortcut |

Newer versions also adjust the auto-brightness mapping while Extra Dim is active.

**Intensity curve.** Strength `s` (0–1) becomes a per-channel factor `a·s² + b·s + c`. There are two coefficient sets, one for linear-space matrices and one for non-linear (gamma) space, chosen by whether the colour pipeline needs linear matrices. In the early AOSP commit this project read, the non-linear set is about `−0.443, −0.243, 0.981` (factor ≈ 0.29 at full strength) and the linear set about `1 − 0.956·s` (≈ 0.04 at full strength). Shipped releases may tune these.

**Probing it from a shell.** `dumpsys color_display` has a `Reduce bright colors:` section that prints ` Activated: …` when the feature is available and ` Not available` when the ROM or HWC didn't enable it.

## 2. Why some ROMs don't have it

- **Android 8–11** have none of the layers above.
- **Android 12+** usually has the framework code, but the ROM/HWC configuration decides whether it is *available*, and OEM or custom builds may leave the tile or the Settings page out.

## 3. What this module does

Two engines, picked automatically on every call:

| Engine | Used when | How |
|---|---|---|
| **sf** | Android 8–11; Android 12+ when Extra Dim is *not available*; or `ENGINE=sf` | `service call SurfaceFlinger 1015 i32 1 <16 floats>`: a uniform RGB scale (`diag(f,f,f,1)`, column-major; SurfaceFlinger requires the last row to be `0,0,0,1`). Reset with `1015 i32 0`. |
| **native** | Android 12+ and `dumpsys color_display` reports it available | Writes `reduce_bright_colors_level`, then `reduce_bright_colors_activated` (plus the persist key). The system does the rest and composes it with Night Light. |

**Safety rule.** On Android 12+ the helper never writes AOSP's `reduce_bright_colors_*` keys unless the framework reports the feature as available. In the AOSP source the service registers observers for those keys regardless, but only loads its colour-transform coefficients when the feature is available, so writing them on an unavailable ROM could produce a wrong matrix. The SurfaceFlinger engine also keeps a floor (`MINF`) so a bad curve can't black the screen out. (A zero matrix does exactly that.)

**State and restarts.** The helper keeps `/data/adb/extradim/state` and mirrors `extradim_on / _level / _persist / _boot` to the secure settings so the tile can read them without root. `Settings.Global boot_count` changes on every restart: a dim from an earlier boot reads as off immediately, unless *Keep on after restart* is set. Android 8–11 additionally mirror AOSP's key names for tile app v1.0.

**Tile app.** A `TileService` plus a settings activity (`QS_TILE_PREFERENCES`). It only calls `su -c extradim …` on a tap or slider release. It ships as a systemless system app (module overlay, no `pm install`), and the boot script adds the tile to Quick Settings once with `cmd statusbar add-tile`.

**Battery check.** `extradim check` counts layers that SurfaceFlinger hands to the display controller (`DEVICE`) versus composes on the GPU (`CLIENT`) in `dumpsys SurfaceFlinger`, before and with the dim. It is a heuristic, not a guarantee.

## 4. Not done (yet)

- Composing with Night Light on the SurfaceFlinger engine (needs a `system_server` patch).
- Re-tuning auto-brightness for the dim.
- A config-overlay route for Android 12+ (flipping `config_setColorTransformAccelerated`). It is ROM-specific and only valid if the HWC really can offload the transform.

## References

- AOSP commit adding reduce-bright-colors to the brightness tracker (API, config flags, coefficients), mirrored by /e/OS: <https://gitlab.e.foundation/e/os/android_frameworks_base/-/commit/057955ebbda61e9ca19f4349d61d6e41f2184319>
- `DisplayTransformManager` (colour-matrix levels and the SurfaceFlinger call): <https://android.googlesource.com/platform/frameworks/base/+/refs/heads/master/services/core/java/com/android/server/display/color/DisplayTransformManager.java>
- `ColorDisplayService` (observers, availability checks, `dumpsys` output): <https://android.googlesource.com/platform/frameworks/base/+/master/services/core/java/com/android/server/display/color/ColorDisplayService.java>
- SurfaceFlinger transaction 1015 in the Night Display commit: <https://android.googlesource.com/platform/frameworks/base/+/297e118%5E%21/>
- SystemUI Quick Settings tile guide: <https://android.googlesource.com/platform/frameworks/base/+/49eed100b49e/packages/SystemUI/docs/qs-tiles.md>
- Another module using the same SurfaceFlinger call on Android 11–14: <https://github.com/adivenxnataly/DisplayCalibration>
- Red Moon issue showing `service call SurfaceFlinger 1015` usage (and that a zero matrix blanks the screen): <https://github.com/LibreShift/red-moon/issues/150>
