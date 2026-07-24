package com.clean.player.ui;

import android.content.Intent;
import android.os.Bundle;
import android.widget.Button;
import android.widget.EditText;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AppCompatActivity;
import androidx.recyclerview.widget.GridLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

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

public class SearchActivity extends AppCompatActivity {
    private VideoAdapter adapter;

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_search);
        EditText et = findViewById(R.id.etKeyword);
        Button btn = findViewById(R.id.btnSearch);
        RecyclerView recycler = findViewById(R.id.recycler);

        adapter = new VideoAdapter(item -> {
            Intent i = new Intent(this, PlayerActivity.class);
            i.putExtra(PlayerActivity.EXTRA_TITLE, item.bestTitle());
            i.putExtra(PlayerActivity.EXTRA_URL, item.bestPlayUrl());
            i.putExtra(PlayerActivity.EXTRA_ID, item.idOrVideoId());
            startActivity(i);
        });
        recycler.setLayoutManager(new GridLayoutManager(this, 2));
        recycler.setAdapter(adapter);

        btn.setOnClickListener(v -> {
            String kw = et.getText() == null ? "" : et.getText().toString().trim();
            if (kw.isEmpty()) {
                Toast.makeText(this, "请输入关键词", Toast.LENGTH_SHORT).show();
                return;
            }
            search(kw);
        });
    }

    private void search(String keyword) {
        Map<String, Object> body = new HashMap<>();
        body.put("page", 1);
        body.put("page_size", 20);
        body.put("keyword", keyword);
        body.put("key", keyword);
        body.put("words", keyword);
        NetManager.api().searchVideo(body).enqueue(new Callback<ApiResponse<VideoListData>>() {
            @Override
            public void onResponse(@NonNull Call<ApiResponse<VideoListData>> call,
                                   @NonNull Response<ApiResponse<VideoListData>> response) {
                List<VideoItem> items = new ArrayList<>();
                if (response.isSuccessful() && response.body() != null
                        && response.body().data != null
                        && response.body().data.items() != null) {
                    items.addAll(response.body().data.items());
                }
                adapter.setItems(items);
                if (items.isEmpty()) {
                    Toast.makeText(SearchActivity.this, "无结果 / 接口可能加密", Toast.LENGTH_SHORT).show();
                }
            }

            @Override
            public void onFailure(@NonNull Call<ApiResponse<VideoListData>> call, @NonNull Throwable t) {
                Toast.makeText(SearchActivity.this, t.getMessage(), Toast.LENGTH_SHORT).show();
            }
        });
    }
}
