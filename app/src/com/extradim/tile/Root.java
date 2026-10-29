package com.extradim.tile;

import android.content.Context;
import android.system.Os;
import android.system.OsConstants;
import java.io.BufferedReader;
import java.io.File;
import java.io.FileDescriptor;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStreamReader;

/**
 * Talks to the module's root helper, two ways, tried in this order:
 *
 * 1. Mailbox: write a one-line command into our own device-protected files folder. The module's
 *    idle root listener runs it and deletes the file. No root grant is needed, so it behaves the
 *    same under Magisk, KernelSU and APatch (those managers hide system apps in their root list).
 *    The listener is either inotifyd (watches the folder) or, on ROMs without inotifyd, a blocking
 *    pipe reader: then the app also pokes cmd.fifo (the .listener marker says which one runs).
 * 2. su: classic "su -c". Needs a root grant. Only used when the listener is not running.
 *
 * Blocking: call off the main thread.
 */
final class Root {
    private static final String HELPER = "/data/adb/modules/extradim/system/bin/extradim";
    private static final long MAILBOX_TIMEOUT_MS = 4000;

    private Root() { }

    /** Returns the helper's output when su was used, "" when the mailbox handled it, null on failure. */
    static String run(Context ctx, String args) {
        if (mailbox(ctx, args)) {
            return "";
        }
        return su(args);
    }

    private static boolean mailbox(Context ctx, String args) {
        try {
            File dir = ctx.createDeviceProtectedStorageContext().getFilesDir();
            File marker = new File(dir, ".listener");
            if (!marker.exists()) {
                return false;
            }
            String kind = firstLine(marker);
            File cmd = new File(dir, "cmd");
            FileOutputStream out = new FileOutputStream(cmd);
            try {
                out.write((args + "\n").getBytes("UTF-8"));
            } finally {
                out.close();
            }
            if ("fifo".equals(kind)) {
                poke(new File(dir, "cmd.fifo"));
            }
            long end = System.currentTimeMillis() + MAILBOX_TIMEOUT_MS;
            while (cmd.exists() && System.currentTimeMillis() < end) {
                Thread.sleep(40);
            }
            if (cmd.exists()) {
                cmd.delete(); // nobody picked it up: don't let it run later
                return false;
            }
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    private static String firstLine(File f) {
        try {
            BufferedReader r = new BufferedReader(new InputStreamReader(new FileInputStream(f), "UTF-8"));
            try {
                String l = r.readLine();
                return l == null ? "" : l.trim();
            } finally {
                r.close();
            }
        } catch (Exception e) {
            return "";
        }
    }

    /** Non-blocking write to the listener's pipe; fails at once (ENXIO/ENOENT) if nobody is reading. */
    private static void poke(File fifo) {
        FileDescriptor fd = null;
        try {
            fd = Os.open(fifo.getPath(), OsConstants.O_WRONLY | OsConstants.O_NONBLOCK, 0);
            Os.write(fd, new byte[] { '\n' }, 0, 1);
        } catch (Exception ignored) {
            // the wait loop in mailbox() times out and falls back to su
        } finally {
            if (fd != null) {
                try {
                    Os.close(fd);
                } catch (Exception ignored) {
                    // nothing to do
                }
            }
        }
    }

    private static String su(String args) {
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
