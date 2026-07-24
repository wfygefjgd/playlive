package com.clean.player.ui;

import android.net.Uri;
import android.os.Bundle;
import android.widget.TextView;
import android.widget.Toast;

import androidx.annotation.Nullable;
import androidx.appcompat.app.AppCompatActivity;

import com.clean.player.R;
import com.clean.player.util.Prefs;
import com.google.android.exoplayer2.ExoPlayer;
import com.google.android.exoplayer2.MediaItem;
import com.google.android.exoplayer2.source.DefaultMediaSourceFactory;
import com.google.android.exoplayer2.ui.PlayerView;
import com.google.android.exoplayer2.upstream.DefaultHttpDataSource;

import java.util.HashMap;
import java.util.Map;

public class PlayerActivity extends AppCompatActivity {
    public static final String EXTRA_TITLE = "title";
    public static final String EXTRA_URL = "url";
    public static final String EXTRA_ID = "id";

    private ExoPlayer player;

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_player);
        TextView tvTitle = findViewById(R.id.tvTitle);
        PlayerView playerView = findViewById(R.id.playerView);

        String title = getIntent().getStringExtra(EXTRA_TITLE);
        String url = getIntent().getStringExtra(EXTRA_URL);
        tvTitle.setText(title == null ? "" : title);

        if (url == null || url.isEmpty()) {
            Toast.makeText(this, "无可播放地址", Toast.LENGTH_SHORT).show();
            finish();
            return;
        }

        Map<String, String> headers = new HashMap<>();
        String cdn = Prefs.get(Prefs.CDN_HEADER);
        if (cdn != null && !cdn.isEmpty()) {
            // original app sets referer from systemBean.cdn_header
            headers.put("Referer", cdn);
            headers.put("referer", cdn);
        }
        headers.put("User-Agent", "Mozilla/5.0 CleanPlayer/1.0");

        DefaultHttpDataSource.Factory httpFactory = new DefaultHttpDataSource.Factory()
                .setDefaultRequestProperties(headers)
                .setAllowCrossProtocolRedirects(true);

        player = new ExoPlayer.Builder(this)
                .setMediaSourceFactory(new DefaultMediaSourceFactory(httpFactory))
                .build();
        playerView.setPlayer(player);
        player.setMediaItem(MediaItem.fromUri(Uri.parse(url)));
        player.prepare();
        player.play();
    }

    @Override
    protected void onStop() {
        super.onStop();
        if (player != null) {
            player.pause();
        }
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        if (player != null) {
            player.release();
            player = null;
        }
    }
}
