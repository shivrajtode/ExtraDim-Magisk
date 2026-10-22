package com.extradim.tile;

import java.io.BufferedReader;
import java.io.InputStreamReader;

/** Runs the module's root helper through su. Blocking: call off the main thread. */
final class Root {
    private static final String HELPER = "/data/adb/modules/extradim/system/bin/extradim";

    private Root() { }

    static String run(String args) {
        Process p = null;
        try {
            String cmd = "if [ -x " + HELPER + " ]; then " + HELPER + " " + args
                    + "; else extradim " + args + "; fi";
            p = new ProcessBuilder("su", "-c", cmd).redirectErrorStream(true).start();
            BufferedReader r = new BufferedReader(new InputStreamReader(p.getInputStream()));
            StringBuilder sb = new StringBuilder();
            String line;
            while ((line = r.readLine()) != null) {
                sb.append(line).append('\n');
            }
            p.waitFor();
            return sb.toString().trim();
        } catch (Exception e) {
            return null;
        } finally {
            if (p != null) {
                p.destroy();
            }
        }
    }
}
