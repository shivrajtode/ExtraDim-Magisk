package com.extradim.tile;

import android.content.Context;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.provider.Settings;
import android.service.quicksettings.Tile;
import android.service.quicksettings.TileService;

/** Quick Settings tile. State is read from Settings.Secure (no root); root is only used to toggle. */
public class DimTileService extends TileService {

    // Our own keys, written by the root helper on every Android version.
    static final String KEY_ON = "extradim_on";
    static final String KEY_LEVEL = "extradim_level";
    static final String KEY_PERSIST = "extradim_persist";
    static final String KEY_BOOT = "extradim_boot";
    // Helper v2.0 on Android 8-11 mirrored AOSP's names instead. On Android 12+ those names
    // belong to the real Extra Dim, so they are never read there.
    static final String LEGACY_ON = "reduce_bright_colors_activated";
    static final String LEGACY_LEVEL = "reduce_bright_colors_level";

    private final Handler ui = new Handler(Looper.getMainLooper());

    private static int secure(Context c, String key, int def) {
        return Settings.Secure.getInt(c.getContentResolver(), key, def);
    }

    /**
     * On only if it was turned on during this boot (or "keep on after restart" is set).
     * After a restart the dim is already gone, so a leftover flag must read as off.
     */
    static boolean isOn(Context c) {
        int on = secure(c, KEY_ON, -1);
        if (on == -1 && Build.VERSION.SDK_INT < 31) {
            on = secure(c, LEGACY_ON, 0);
        }
        if (on != 1) {
            return false;
        }
        if (keepOn(c)) {
            return true;
        }
        int saved = secure(c, KEY_BOOT, -1);
        int now = Settings.Global.getInt(c.getContentResolver(), "boot_count", -1);
        return saved == -1 || now == -1 || saved == now;
    }

    static int level(Context c) {
        int l = secure(c, KEY_LEVEL, -1);
        if (l == -1 && Build.VERSION.SDK_INT < 31) {
            l = secure(c, LEGACY_LEVEL, -1);
        }
        return l == -1 ? 40 : l;
    }

    static boolean keepOn(Context c) {
        return secure(c, KEY_PERSIST, 0) == 1;
    }

    @Override
    public void onTileAdded() {
        refresh(null);
    }

    @Override
    public void onStartListening() {
        refresh(null);
    }

    @Override
    public void onClick() {
        new Thread(new Runnable() {
            @Override
            public void run() {
                final String out = Root.run("toggle");
                ui.post(new Runnable() {
                    @Override
                    public void run() {
                        refresh(out);
                    }
                });
            }
        }).start();
    }

    private void refresh(String out) {
        Tile t = getQsTile();
        if (t == null) {
            return;
        }
        boolean on = isOn(this);
        int lvl = level(this);
        if (out != null) {
            String last = out.substring(out.lastIndexOf('\n') + 1).trim();
            if (last.startsWith("on ")) {
                on = true;
                lvl = toInt(last.substring(3), lvl);
            } else if (last.startsWith("off ")) {
                on = false;
                lvl = toInt(last.substring(4), lvl);
            }
        }
        t.setState(on ? Tile.STATE_ACTIVE : Tile.STATE_INACTIVE);
        t.setLabel("Extra dim");
        if (Build.VERSION.SDK_INT >= 29) {
            try {
                Tile.class.getMethod("setSubtitle", CharSequence.class)
                        .invoke(t, on ? (lvl + "%") : "Off");
            } catch (Exception ignored) {
                // subtitle is cosmetic
            }
        }
        t.updateTile();
    }

    private static int toInt(String s, int def) {
        try {
            return Integer.parseInt(s.trim());
        } catch (NumberFormatException e) {
            return def;
        }
    }
}
