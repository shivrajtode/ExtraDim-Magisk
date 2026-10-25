package com.extradim.tile;

import android.app.Activity;
import android.os.Bundle;
import android.widget.CompoundButton;
import android.widget.LinearLayout;
import android.widget.SeekBar;
import android.widget.Switch;
import android.widget.TextView;

/** Opened by long-pressing the tile (QS_TILE_PREFERENCES) or from the app drawer. */
public class SettingsActivity extends Activity {

    private Switch swOn;
    private Switch swKeep;
    private SeekBar bar;
    private TextView lbl;
    private boolean updating;

    @Override
    protected void onCreate(Bundle b) {
        super.onCreate(b);
        setTitle("Extra dim");
        int pad = (int) (20 * getResources().getDisplayMetrics().density);

        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(pad, pad, pad, pad);

        swOn = new Switch(this);
        swOn.setText("Use extra dim");
        swOn.setTextSize(18);
        root.addView(swOn);

        lbl = new TextView(this);
        lbl.setPadding(0, pad, 0, 0);
        root.addView(lbl);

        bar = new SeekBar(this);
        bar.setMax(100);
        root.addView(bar);

        TextView hint = new TextView(this);
        hint.setText("Higher = dimmer");
        hint.setAlpha(0.6f);
        root.addView(hint);

        swKeep = new Switch(this);
        swKeep.setText("Keep on after device restarts");
        swKeep.setPadding(0, pad, 0, 0);
        root.addView(swKeep);

        TextView credit = new TextView(this);
        credit.setText("Made with \u2764\uFE0F by t.me/Shivraj_editx");
        credit.setPadding(0, pad * 2, 0, 0);
        credit.setAlpha(0.6f);
        root.addView(credit);

        setContentView(root);

        swOn.setOnCheckedChangeListener(new CompoundButton.OnCheckedChangeListener() {
            @Override
            public void onCheckedChanged(CompoundButton v, boolean checked) {
                if (!updating) {
                    bg(checked ? "on" : "off");
                }
            }
        });
        swKeep.setOnCheckedChangeListener(new CompoundButton.OnCheckedChangeListener() {
            @Override
            public void onCheckedChanged(CompoundButton v, boolean checked) {
                if (!updating) {
                    bg("persist " + (checked ? 1 : 0));
                }
            }
        });
        bar.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
            @Override
            public void onProgressChanged(SeekBar s, int p, boolean fromUser) {
                lbl.setText("Intensity: " + p + "%");
            }

            @Override
            public void onStartTrackingTouch(SeekBar s) { }

            @Override
            public void onStopTrackingTouch(SeekBar s) {
                if (!updating) {
                    bg("level " + s.getProgress());
                }
            }
        });
    }

    @Override
    protected void onResume() {
        super.onResume();
        updating = true;
        swOn.setChecked(DimTileService.isOn(this));
        swKeep.setChecked(DimTileService.keepOn(this));
        bar.setProgress(DimTileService.level(this));
        updating = false;
    }

    private void bg(final String args) {
        new Thread(new Runnable() {
            @Override
            public void run() {
                Root.run(getApplicationContext(), args);
            }
        }).start();
    }
}
