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

**Native engine check.** After writing the Extra Dim settings, the helper reads `dumpsys color_display` again. If the framework still reports Extra Dim as not activated, it undoes the write, stores `ENGINE=sf` in the config and applies the SurfaceFlinger matrix instead (`extradim engine auto` reverts). If the screen still doesn't dim, `extradim diag probe` shows the raw SurfaceFlinger reply and the transform line in its dump.

**Safety rule.** On Android 12+ the helper never writes AOSP's `reduce_bright_colors_*` keys unless the framework reports the feature as available. In the AOSP source the service registers observers for those keys regardless, but only loads its colour-transform coefficients when the feature is available, so writing them on an unavailable ROM could produce a wrong matrix. The SurfaceFlinger engine also keeps a floor (`MINF`) so a bad curve can't black the screen out. (A zero matrix does exactly that.)

**State and restarts.** The helper keeps `/data/adb/extradim/state` and mirrors `extradim_on / _level / _persist / _boot` to the secure settings so the tile can read them without root. `Settings.Global boot_count` changes on every restart: a dim from an earlier boot reads as off immediately, unless *Keep on after restart* is set. Android 8–11 additionally mirror AOSP's key names for tile app v1.0.

**Tile app.** A `TileService` plus a settings activity (`QS_TILE_PREFERENCES`). On a tap or slider release it sends one command to the helper (see section 4). It ships as a systemless system app (module overlay, no `pm install`), and the boot script adds the tile to Quick Settings once with `cmd statusbar add-tile`.

**Battery check.** `extradim check` counts layers that SurfaceFlinger hands to the display controller (`DEVICE`) versus composes on the GPU (`CLIENT`) in `dumpsys SurfaceFlinger`, before and with the dim. It is a heuristic, not a guarantee.

## 4. Root access without a grant

The tile app needs root to run the helper, but KernelSU and APatch have no command a module can use to grant root to an app, and they hide system apps in their root list (the tile app is a system app). So the module avoids needing a grant:

1. `service.sh` starts one idle listener on the app's private, device-protected folder (`/data/user_de/0/com.extradim.tile/files`) and writes a `.listener` marker there that names its kind. It looks for `inotifyd` in toybox and in the Magisk/KernelSU/APatch busybox; on ROMs without it, a tiny shell loop blocks on a named pipe (`cmd.fifo`, opened read-write so it never sees EOF) instead. Neither polls.
2. The app writes a one-line command (`toggle`, `on 40`, `level 70`, `persist 1` ...) into `files/cmd` (and, for the pipe variant, pokes `cmd.fifo` without blocking). Only that app can write there.
3. `cmd-handler.sh` (root) validates the line against a whitelist of words and digits, runs the helper, and deletes `cmd`. The app waits for the file to disappear (4 s at most), then reads the new state from the secure settings.
4. If the listener isn't running (neither mechanism works, or opted out with `touch /data/adb/extradim/no-listener`), the app falls back to `su -c`. `/data/adb/extradim/boot.log` records what the boot script did and `extradim diag` prints it.

On **Magisk** the boot script additionally inserts a root grant for the app into Magisk's policy table (`magisk --sqlite`, policy `2` = allow, no toast), but only when the app has no entry yet, so a choice made in Magisk is never overridden.

## 5. When the display driver ignores colour transforms

SurfaceFlinger holds the matrix (it shows up as `colorTransformMatrix` in `dumpsys SurfaceFlinger`, which `extradim diag` prints), and normally the display HAL applies it to the overlay layers in hardware. On some ROMs (typically a new Android on an older vendor stack) the HAL accepts the call and does nothing, so the matrix is present but the panel doesn't change. Android's own Extra Dim, Night Light and reading modes fail the same way, which is how you recognise it.

`extradim gpu on` works around it: while the dim is on, the helper forces GPU composition (binder code 1008, the switch behind Developer options → *Disable HW overlays*), so SurfaceFlinger applies the matrix while composing and the HAL's transform support isn't needed. The helper gives HWC composition back when the dim goes off, and only if it was the one that forced it. The price is GPU work on every frame while dimmed.

## 6. Not done (yet)

- Composing with Night Light on the SurfaceFlinger engine (needs a `system_server` patch).
- Re-tuning auto-brightness for the dim.
- A config-overlay route for Android 12+ (flipping `config_setColorTransformAccelerated`). It is ROM-specific and only valid if the HWC really can offload the transform.
- Confirming the no-grant path on more KernelSU and APatch devices (it has been seen working on KernelSU-family ksud 4.2 / Android 16).
- A backlight-scaling engine for panels where neither the hardware transform nor GPU composition dims (`extradim diag` already lists the backlight nodes).

## References

- AOSP commit adding reduce-bright-colors to the brightness tracker (API, config flags, coefficients), mirrored by /e/OS: <https://gitlab.e.foundation/e/os/android_frameworks_base/-/commit/057955ebbda61e9ca19f4349d61d6e41f2184319>
- `DisplayTransformManager` (colour-matrix levels and the SurfaceFlinger call): <https://android.googlesource.com/platform/frameworks/base/+/refs/heads/master/services/core/java/com/android/server/display/color/DisplayTransformManager.java>
- `ColorDisplayService` (observers, availability checks, `dumpsys` output): <https://android.googlesource.com/platform/frameworks/base/+/master/services/core/java/com/android/server/display/color/ColorDisplayService.java>
- SurfaceFlinger transaction 1015 in the Night Display commit: <https://android.googlesource.com/platform/frameworks/base/+/297e118%5E%21/>
- SystemUI Quick Settings tile guide: <https://android.googlesource.com/platform/frameworks/base/+/49eed100b49e/packages/SystemUI/docs/qs-tiles.md>
- Another module using the same SurfaceFlinger call on Android 11–14: <https://github.com/adivenxnataly/DisplayCalibration>
- KernelSU request for granting root from the shell (still no official command): <https://github.com/tiann/KernelSU/issues/1695>
- Magisk tools (`magisk --sqlite`): <https://magisk.readthedocs.io/en/latest/developers/tools.html>
- Red Moon issue showing `service call SurfaceFlinger 1015` usage (and that a zero matrix blanks the screen): <https://github.com/LibreShift/red-moon/issues/150>
