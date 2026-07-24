package com.clean.player.net;

import androidx.annotation.NonNull;

import com.clean.player.util.DeviceUtil;
import com.clean.player.util.Prefs;

import java.io.IOException;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;
import java.util.TimeZone;

import okhttp3.Interceptor;
import okhttp3.Request;
import okhttp3.Response;

/**
 * Mirrors recovered request headers from original interceptor (oj0.smali):
 * User-Agent, deviceType, version, time, and token when present.
 */
public class HeaderInterceptor implements Interceptor {
    private static final String UA =
            "Mozilla/5.0 (Linux; U; Android 8.1.0; zh-CN; EML-AL00 Build/HUAWEIEML-AL00) "
                    + "AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/57.0.2987.108 "
                    + "Mobile Safari/537.36 CleanPlayer/1.0";

    @NonNull
    @Override
    public Response intercept(@NonNull Chain chain) throws IOException {
        Request original = chain.request();
        SimpleDateFormat sdf = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.CHINA);
        sdf.setTimeZone(TimeZone.getTimeZone("GMT+08"));
        String time = sdf.format(new Date());
        String token = Prefs.get(Prefs.USER_TOKEN);

        Request.Builder b = original.newBuilder()
                .header("User-Agent", UA)
                .header("deviceType", "android")
                .header("version", "4.1.9")
                .header("time", time)
                .header("device_id", DeviceUtil.deviceId());

        if (token != null && !token.isEmpty()) {
            b.header("token", token);
            b.header("Authorization", token);
        }

        return chain.proceed(b.build());
    }
}
