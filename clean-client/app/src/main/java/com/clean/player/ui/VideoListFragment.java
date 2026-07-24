package com.clean.player.ui;

import android.content.Intent;
import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;
import androidx.recyclerview.widget.GridLayoutManager;
import androidx.recyclerview.widget.RecyclerView;
import androidx.swiperefreshlayout.widget.SwipeRefreshLayout;

import com.clean.player.R;
import com.clean.player.model.ApiResponse;
import com.clean.player.model.VideoItem;
import com.clean.player.model.VideoListData;
import com.clean.player.net.NetManager;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import retrofit2.Call;
import retrofit2.Callback;
import retrofit2.Response;

public class VideoListFragment extends Fragment {
    private static final String ARG_MODE = "mode";
    private static final int MODE_HOME = 0;
    private static final int MODE_SHORT = 1;
    private static final int MODE_SEARCH = 2;

    private SwipeRefreshLayout swipe;
    private RecyclerView recycler;
    private TextView tvEmpty;
    private VideoAdapter adapter;
    private int mode = MODE_HOME;
    private int page = 1;
    private String keyword = "";

    public static VideoListFragment home() {
        return create(MODE_HOME, "");
    }

    public static VideoListFragment shorts() {
        return create(MODE_SHORT, "");
    }

    public static VideoListFragment search(String keyword) {
        return create(MODE_SEARCH, keyword);
    }

    private static VideoListFragment create(int mode, String keyword) {
        VideoListFragment f = new VideoListFragment();
        Bundle b = new Bundle();
        b.putInt(ARG_MODE, mode);
        b.putString("keyword", keyword);
        f.setArguments(b);
        return f;
    }

    @Nullable
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, @Nullable ViewGroup container,
                             @Nullable Bundle savedInstanceState) {
        return inflater.inflate(R.layout.fragment_video_list, container, false);
    }

    @Override
    public void onViewCreated(@NonNull View view, @Nullable Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);
        if (getArguments() != null) {
            mode = getArguments().getInt(ARG_MODE, MODE_HOME);
            keyword = getArguments().getString("keyword", "");
        }
        swipe = view.findViewById(R.id.swipe);
        recycler = view.findViewById(R.id.recycler);
        tvEmpty = view.findViewById(R.id.tvEmpty);
        adapter = new VideoAdapter(item -> {
            Intent i = new Intent(requireContext(), PlayerActivity.class);
            i.putExtra(PlayerActivity.EXTRA_TITLE, item.bestTitle());
            i.putExtra(PlayerActivity.EXTRA_URL, item.bestPlayUrl());
            i.putExtra(PlayerActivity.EXTRA_ID, item.idOrVideoId());
            startActivity(i);
        });
        recycler.setLayoutManager(new GridLayoutManager(requireContext(), 2));
        recycler.setAdapter(adapter);
        swipe.setOnRefreshListener(() -> {
            page = 1;
            load();
        });
        load();
    }

    public void setKeywordAndReload(String kw) {
        this.keyword = kw == null ? "" : kw;
        this.mode = MODE_SEARCH;
        this.page = 1;
        load();
    }

    private void load() {
        swipe.setRefreshing(true);
        Map<String, Object> body = new HashMap<>();
        body.put("page", page);
        body.put("page_size", 20);
        body.put("pageSize", 20);
        if (mode == MODE_SEARCH) {
            body.put("keyword", keyword);
            body.put("key", keyword);
            body.put("words", keyword);
        }

        Call<ApiResponse<VideoListData>> call;
        if (mode == MODE_SHORT) {
            call = NetManager.api().shortRecommend(body);
        } else if (mode == MODE_SEARCH) {
            call = NetManager.api().searchVideo(body);
        } else {
            call = NetManager.api().homeRecommend(body);
        }

        call.enqueue(new Callback<ApiResponse<VideoListData>>() {
            @Override
            public void onResponse(@NonNull Call<ApiResponse<VideoListData>> call,
                                   @NonNull Response<ApiResponse<VideoListData>> response) {
                swipe.setRefreshing(false);
                List<VideoItem> items = new ArrayList<>();
                if (response.isSuccessful() && response.body() != null) {
                    ApiResponse<VideoListData> body = response.body();
                    if (body.data != null && body.data.items() != null) {
                        items.addAll(body.data.items());
                    }
                }
                adapter.setItems(items);
                tvEmpty.setVisibility(items.isEmpty() ? View.VISIBLE : View.GONE);
                if (items.isEmpty() && response.code() != 200) {
                    Toast.makeText(requireContext(),
                            "接口返回 " + response.code() + "（可能需 AES 封装，见 README）",
                            Toast.LENGTH_LONG).show();
                }
            }

            @Override
            public void onFailure(@NonNull Call<ApiResponse<VideoListData>> call, @NonNull Throwable t) {
                swipe.setRefreshing(false);
                tvEmpty.setVisibility(View.VISIBLE);
                Toast.makeText(requireContext(), "加载失败: " + t.getMessage(), Toast.LENGTH_SHORT).show();
            }
        });
    }
}
