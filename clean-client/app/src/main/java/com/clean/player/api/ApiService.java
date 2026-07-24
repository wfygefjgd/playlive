package com.clean.player.api;

import com.clean.player.model.ApiResponse;
import com.clean.player.model.SystemInfo;
import com.clean.player.model.UserInfo;
import com.clean.player.model.VideoItem;
import com.clean.player.model.VideoListData;
import com.google.gson.JsonObject;

import java.util.Map;

import okhttp3.RequestBody;
import okhttp3.ResponseBody;
import retrofit2.Call;
import retrofit2.http.Body;
import retrofit2.http.FieldMap;
import retrofit2.http.FormUrlEncoded;
import retrofit2.http.GET;
import retrofit2.http.POST;
import retrofit2.http.Query;
import retrofit2.http.QueryMap;
import retrofit2.http.Url;

/**
 * Endpoints recovered from original APK (short obfuscated paths).
 * Ads / pay-wall / social spam endpoints intentionally omitted.
 */
public interface ApiService {

    // ---- boot / system ----
    /** system info + token bootstrap (from SplashViewMode: yh/xx) */
    @POST("yh/xx")
    Call<ApiResponse<SystemInfo>> systemInfo(@Body Map<String, Object> body);

    /** line ping (from SplashViewMode: xl/p) */
    @GET("xl/p")
    Call<ResponseBody> ping();

    @GET
    Call<ResponseBody> pingUrl(@Url String url);

    // ---- account (minimal) ----
    @POST("user/baseInfo")
    Call<ApiResponse<UserInfo>> userBaseInfo(@Body Map<String, Object> body);

    @POST("yh/dl")
    Call<ApiResponse<JsonObject>> login(@Body Map<String, Object> body);

    @POST("yh/qrzh")
    Call<ApiResponse<JsonObject>> restoreAccount(@Body Map<String, Object> body);

    // ---- video list / detail (core) ----
    /** home list recommend */
    @POST("sp/sytj")
    Call<ApiResponse<VideoListData>> homeRecommend(@Body Map<String, Object> body);

    /** home module / category */
    @POST("sp/sybq")
    Call<ApiResponse<VideoListData>> homeCategory(@Body Map<String, Object> body);

    /** home more / up */
    @POST("sp/syup")
    Call<ApiResponse<VideoListData>> homeMore(@Body Map<String, Object> body);

    /** search video */
    @POST("sp/gjc")
    Call<ApiResponse<VideoListData>> searchVideo(@Body Map<String, Object> body);

    /** short recommend */
    @POST("sp/xq")
    Call<ApiResponse<VideoListData>> shortRecommend(@Body Map<String, Object> body);

    /** short follow feed */
    @POST("sp/dygz")
    Call<ApiResponse<VideoListData>> shortFollow(@Body Map<String, Object> body);

    /** video detail-ish */
    @POST("sp/xzsp")
    Call<ApiResponse<VideoItem>> videoDetail(@Body Map<String, Object> body);

    /** tags */
    @POST("tag/list")
    Call<ApiResponse<JsonObject>> tagList(@Body Map<String, Object> body);

    @POST("tag/info")
    Call<ApiResponse<JsonObject>> tagInfo(@Body Map<String, Object> body);

    // ---- history / love (local-useful, no ad) ----
    @POST("video/historyList")
    Call<ApiResponse<VideoListData>> historyList(@Body Map<String, Object> body);

    @POST("video/loveList")
    Call<ApiResponse<VideoListData>> loveList(@Body Map<String, Object> body);

    @POST("video/shortList")
    Call<ApiResponse<VideoListData>> shortList(@Body Map<String, Object> body);

    // generic flexible POST for probing
    @POST
    Call<ResponseBody> rawPost(@Url String url, @Body RequestBody body);

    @FormUrlEncoded
    @POST
    Call<ResponseBody> rawForm(@Url String url, @FieldMap Map<String, String> fields);

    @GET
    Call<ResponseBody> rawGet(@Url String url, @QueryMap Map<String, String> query);
}
