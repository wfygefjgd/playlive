package com.clean.player.util;

import android.os.Build;
import android.provider.Settings;

import com.clean.player.App;

import java.util.UUID;

public final class DeviceUtil {
    private DeviceUtil() {}

    public static String deviceId() {
        String saved = Prefs.get(Prefs.SP_DEVICE_ID);
        if (saved != null && !saved.isEmpty()) {
            return saved;
        }
        String androidId = Settings.Secure.getString(
                App.get().getContentResolver(), Settings.Secure.ANDROID_ID);
        if (androidId == null || androidId.isEmpty() || "9774d56d682e549c".equals(androidId)) {
            androidId = UUID.randomUUID().toString().replace("-", "");
        }
        Prefs.put(Prefs.SP_DEVICE_ID, androidId);
        return androidId;
    }

    public static String deviceInfo() {
        return Build.MANUFACTURER + " " + Build.MODEL + " Android " + Build.VERSION.RELEASE;
    }
}
