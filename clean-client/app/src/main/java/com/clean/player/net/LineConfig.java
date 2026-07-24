package com.clean.player.net;

import com.clean.player.util.Prefs;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

/**
 * Base URLs recovered from original APK AndroidManifest DEFAULT_LINKS
 * and hard-coded fallback.
 *
 * NOTE: AES key / nativeGetDefaultUrl still live in libsecurity.so.
 * Line check picks the first reachable /v1/ endpoint.
 */
public final class LineConfig {
    public static final List<String> DEFAULT_LINKS = Arrays.asList(
            "http://gjsqj.z1zhql1q.com/v1/",
            "http://gjsqj.lld9co260rth241tby8tgc5f02xx8.com/v1/",
            "http://bak.hvw75f69.com/v1/",
            "http://107.148.37.172:8891/v1/"
    );

    private LineConfig() {}

    public static List<String> all() {
        List<String> list = new ArrayList<>();
        String saved = Prefs.get(Prefs.SP_BASE_URL);
        if (saved != null && !saved.isEmpty()) {
            list.add(ensureSlash(saved));
        }
        for (String u : DEFAULT_LINKS) {
            String e = ensureSlash(u);
            if (!list.contains(e)) {
                list.add(e);
            }
        }
        return list;
    }

    public static String current() {
        String saved = Prefs.get(Prefs.SP_BASE_URL);
        if (saved != null && !saved.isEmpty()) {
            return ensureSlash(saved);
        }
        return DEFAULT_LINKS.get(0);
    }

    public static void setCurrent(String url) {
        Prefs.put(Prefs.SP_BASE_URL, ensureSlash(url));
    }

    private static String ensureSlash(String url) {
        if (url == null || url.isEmpty()) {
            return url;
        }
        return url.endsWith("/") ? url : url + "/";
    }
}
