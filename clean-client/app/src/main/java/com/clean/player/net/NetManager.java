package com.clean.player.net;

import com.clean.player.api.ApiService;

import java.util.concurrent.TimeUnit;

import okhttp3.OkHttpClient;
import okhttp3.logging.HttpLoggingInterceptor;
import retrofit2.Retrofit;
import retrofit2.converter.gson.GsonConverterFactory;

public final class NetManager {
    private static OkHttpClient client;
    private static ApiService api;

    private NetManager() {}

    public static void init() {
        HttpLoggingInterceptor log = new HttpLoggingInterceptor();
        log.setLevel(HttpLoggingInterceptor.Level.BASIC);

        client = new OkHttpClient.Builder()
                .connectTimeout(15, TimeUnit.SECONDS)
                .readTimeout(30, TimeUnit.SECONDS)
                .writeTimeout(30, TimeUnit.SECONDS)
                .addInterceptor(new HeaderInterceptor())
                .addInterceptor(log)
                .retryOnConnectionFailure(true)
                .build();

        rebuild();
    }

    public static void rebuild() {
        Retrofit retrofit = new Retrofit.Builder()
                .baseUrl(LineConfig.current())
                .client(client)
                .addConverterFactory(GsonConverterFactory.create())
                .build();
        api = retrofit.create(ApiService.class);
    }

    public static ApiService api() {
        if (api == null) {
            init();
        }
        return api;
    }

    public static OkHttpClient client() {
        if (client == null) {
            init();
        }
        return client;
    }
}
