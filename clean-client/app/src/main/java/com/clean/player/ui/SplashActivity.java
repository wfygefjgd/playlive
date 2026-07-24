package com.clean.player.ui;

import android.content.Intent;
import android.os.Bundle;
import android.widget.TextView;
import android.widget.Toast;

import androidx.annotation.Nullable;
import androidx.appcompat.app.AppCompatActivity;

import com.clean.player.R;
import com.clean.player.model.ApiResponse;
import com.clean.player.model.SystemInfo;
import com.clean.player.net.LineConfig;
import com.clean.player.net.NetManager;
import com.clean.player.util.DeviceUtil;
import com.clean.player.util.Prefs;
import com.google.gson.Gson;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import okhttp3.Request;
import okhttp3.Response;
import retrofit2.Call;

/**
 * Line check + system bootstrap. No splash ads / force update ads.
 */
public class SplashActivity extends AppCompatActivity {
    private TextView tvStatus;
    private final ExecutorService io = Executors.newSingleThreadExecutor();
    private final Gson gson = new Gson();

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_splash);
        tvStatus = findViewById(R.id.tvStatus);
        io.execute(this::boot);
    }

    private void boot() {
        setStatus("线路检测中…");
        String best = pickLine();
        if (best == null) {
            setStatus("线路不可用，使用默认线路");
            best = LineConfig.DEFAULT_LINKS.get(0);
        }
        LineConfig.setCurrent(best);
        runOnUiThread(NetManager::rebuild);

        setStatus("初始化系统信息…");
        try {
            Map<String, Object> body = new HashMap<>();
            body.put("device_id", DeviceUtil.deviceId());
            body.put("clipboard_text", "");
            body.put("app_code", "clean");
            body.put("channel_code", "");
            body.put("domain", best);
            body.put("ad_method", "none");
            body.put("device_info", DeviceUtil.deviceInfo());
            body.put("device_information", DeviceUtil.deviceInfo());

            Call<ApiResponse<SystemInfo>> call = NetManager.api().systemInfo(body);
            retrofit2.Response<ApiResponse<SystemInfo>> resp = call.execute();
            if (resp.isSuccessful() && resp.body() != null && resp.body().data != null) {
                SystemInfo info = resp.body().data;
                Prefs.put(Prefs.SYSTEM_INFO, gson.toJson(info));
                if (info.cdn_header != null) {
                    Prefs.put(Prefs.CDN_HEADER, info.cdn_header);
                }
                if (info.token != null && info.token.token != null) {
                    Prefs.put(Prefs.USER_TOKEN, info.token.token);
                }
            }
        } catch (Exception e) {
            // continue even if system endpoint shape differs
            e.printStackTrace();
        }

        runOnUiThread(() -> {
            startActivity(new Intent(this, MainActivity.class));
            finish();
        });
    }

    private String pickLine() {
        List<String> lines = LineConfig.all();
        for (String base : lines) {
            try {
                setStatus("检测: " + base);
                // ping relative path xl/p
                Request req = new Request.Builder()
                        .url(base + "xl/p")
                        .get()
                        .header("User-Agent", "CleanPlayer/1.0")
                        .build();
                try (Response resp = NetManager.client().newCall(req).execute()) {
                    if (resp.isSuccessful() || (resp.code() >= 200 && resp.code() < 500)) {
                        // 4xx still means host is reachable for some APIs
                        if (resp.code() != 404) {
                            return base;
                        }
                    }
                }
                // fallback: host root
                Request root = new Request.Builder().url(base).get().build();
                try (Response resp = NetManager.client().newCall(root).execute()) {
                    if (resp.code() > 0) {
                        return base;
                    }
                }
            } catch (Exception ignored) {
            }
        }
        return null;
    }

    private void setStatus(String s) {
        runOnUiThread(() -> {
            if (tvStatus != null) tvStatus.setText(s);
        });
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        io.shutdownNow();
    }
}
