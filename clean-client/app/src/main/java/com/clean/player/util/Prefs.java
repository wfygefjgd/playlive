package com.clean.player.util;

import android.content.Context;
import android.content.SharedPreferences;

public final class Prefs {
    private static SharedPreferences sp;

    public static final String SP_BASE_URL = "SP_BASE_URL";
    public static final String USER_TOKEN = "USER_TOKEN";
    public static final String SP_DEVICE_ID = "SP_DEVICE_ID";
    public static final String SYSTEM_INFO = "SYSTEM_INFO";
    public static final String USER_INFO = "USER_INFO";
    public static final String CDN_HEADER = "CDN_HEADER";

    private Prefs() {}

    public static void init(Context context) {
        sp = context.getSharedPreferences("clean_player", Context.MODE_PRIVATE);
    }

    public static void put(String key, String value) {
        sp.edit().putString(key, value == null ? "" : value).apply();
    }

    public static String get(String key, String def) {
        return sp.getString(key, def);
    }

    public static String get(String key) {
        return get(key, "");
    }
}
