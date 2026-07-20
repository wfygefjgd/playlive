package org.tvplayer.app;

import android.app.AlertDialog;
import android.content.Context;
import android.content.pm.ActivityInfo;
import android.net.ConnectivityManager;
import android.net.NetworkInfo;
import android.media.AudioManager;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.provider.Settings;
import android.text.InputType;
import android.view.KeyEvent;
import android.view.GestureDetector;
import android.view.MotionEvent;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.ListView;
import android.widget.TextView;
import android.widget.Toast;
import android.view.inputmethod.InputMethodManager;

import androidx.annotation.Nullable;
import androidx.appcompat.app.AppCompatActivity;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import android.widget.ArrayAdapter;

import com.google.android.exoplayer2.C;
import com.google.android.exoplayer2.ExoPlayer;
import com.google.android.exoplayer2.MediaItem;
import com.google.android.exoplayer2.Player;
import com.google.android.exoplayer2.ui.PlayerView;

import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class MainActivity extends AppCompatActivity {

    private static final String DEFAULT_SOURCE_URL = "https://raw.githubusercontent.com/best-fan/iptv-sources/master/cn_all_status.m3u8";
    private static final String[] DEFAULT_MIRRORS = {
            DEFAULT_SOURCE_URL,
            "https://ghfast.top/raw.githubusercontent.com/best-fan/iptv-sources/master/cn_all_status.m3u8",
            "https://raw.gitmirror.com/best-fan/iptv-sources/master/cn_all_status.m3u8",
            "https://raw.kkgithub.com/best-fan/iptv-sources/master/cn_all_status.m3u8"
    };
    private static final long CHANNEL_OSD_MS = 2500L;
    private static final long CHANNEL_SWITCH_TIMEOUT_MS = 7000L;
    private static final long STALL_TIMEOUT_MS = 7000L;
    private static final long NETWORK_WAIT_RETRY_MS = 1000L;
    private static final long FLOAT_BUTTONS_TIMEOUT_MS = 2500L;

    private PlayerView playerView;
    private ExoPlayer player;
    private View leftPanel;
    private Button btnTogglePanel;
    private Button btnLock;
    private TextView status;
    private TextView channelLabel;
    private TextView indicator;
    private RecyclerView channelList;

    private final List<Channel> channels = new ArrayList<>();
    private final List<String> sourceUrls = new ArrayList<>();
    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private final ExecutorService netPool = Executors.newFixedThreadPool(2);

    private ChannelAdapter adapter;
    private AudioManager audioManager;
    private StorageHelper storage;
    private GestureDetector gestureDetector;
    private Runnable hideIndicatorRunnable;
    private Runnable hideChannelLabelRunnable;
    private Runnable stallRunnable;
    private Runnable silentAudioRunnable;
    private Runnable hideFloatingButtonsRunnable;

    private int currentIndex = 0;
    private int currentSourceIndex = 0;
    private boolean panelVisible = false;
    private boolean locked = false;
    private boolean loading = false;
    private boolean waitingForReady = false;
    private float brightness = 0.5f;
    private int playbackToken = 0;
    private String activeSourceUrl = DEFAULT_SOURCE_URL;
    private boolean autoSwitchingSource = false;
    private boolean currentPlaybackReachedReady = false;
    private long pendingStallTimeoutMs = CHANNEL_SWITCH_TIMEOUT_MS;

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        requestWindowFeature(Window.FEATURE_NO_TITLE);
        getWindow().setFlags(
                WindowManager.LayoutParams.FLAG_FULLSCREEN,
                WindowManager.LayoutParams.FLAG_FULLSCREEN);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE);

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            WindowManager.LayoutParams lp = getWindow().getAttributes();
            lp.layoutInDisplayCutoutMode =
                    WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES;
            getWindow().setAttributes(lp);
        }

        setContentView(R.layout.activity_main);
        audioManager = (AudioManager) getSystemService(AUDIO_SERVICE);
        storage = new StorageHelper(this);
        restoreSourceState();

        bindViews();
        setupPlayer();
        setupList();
        setupGestures();
        setupButtons();
        loadBrightness();
        loadChannels();
    }

    private void bindViews() {
        playerView = findViewById(R.id.player_view);
        leftPanel = findViewById(R.id.left_panel);
        btnTogglePanel = findViewById(R.id.btn_toggle_panel);
        btnLock = findViewById(R.id.btn_lock);
        status = findViewById(R.id.status);
        channelLabel = findViewById(R.id.channel_label);
        indicator = findViewById(R.id.indicator);
        channelList = findViewById(R.id.channel_list);

        playerView.setUseController(false);
        playerView.setKeepContentOnPlayerReset(true);
        channelLabel.setVisibility(View.GONE);
        status.setVisibility(View.VISIBLE);
        setFloatingButtonsVisible(true);
        leftPanel.setVisibility(View.GONE);
        btnTogglePanel.setText("▶");
    }

    private void setupPlayer() {
        player = new ExoPlayer.Builder(this).build();
        playerView.setPlayer(player);
        player.addListener(new Player.Listener() {
            @Override
            public void onPlaybackStateChanged(int state) {
                if (state == Player.STATE_READY) {
                    waitingForReady = false;
                    autoSwitchingSource = false;
                    currentPlaybackReachedReady = true;
                    cancelStallCheck();
                    scheduleSilentAudioCheck();
                    scheduleHideFloatingButtons();
                    return;
                }
                cancelSilentAudioCheck();
                if (state == Player.STATE_BUFFERING || state == Player.STATE_IDLE || state == Player.STATE_ENDED) {
                    scheduleStallCheck(currentPlaybackReachedReady ? STALL_TIMEOUT_MS : pendingStallTimeoutMs);
                }
            }

            @Override
            public void onPlayerError(com.google.android.exoplayer2.PlaybackException error) {
                mainHandler.post(() -> {
                    waitingForReady = false;
                    cancelStallCheck();
                    switchToNextPlayableSource("当前线路播放失败，切换下一线路", true);
                });
            }
        });
    }

    private void setupList() {
        adapter = new ChannelAdapter();
        channelList.setLayoutManager(new LinearLayoutManager(this));
        channelList.setAdapter(adapter);
        adapter.setOnChannelClick(position -> {
            if (locked) {
                return;
            }
            currentIndex = position;
            currentSourceIndex = 0;
            playCurrent(true);
        });
    }

    private void setupButtons() {
        btnTogglePanel.setOnClickListener(v -> {
            if (!locked) {
                togglePanel();
            }
        });
        btnTogglePanel.setOnLongClickListener(v -> {
            if (!locked) {
                showSourceInputDialog();
            }
            return true;
        });
        btnLock.setOnClickListener(v -> toggleLock());
        btnLock.setOnLongClickListener(v -> {
            if (!channels.isEmpty()) {
                confirmDeleteCurrentLine();
            }
            return true;
        });
    }

    private void setupGestures() {
        gestureDetector = new GestureDetector(this, new GestureDetector.SimpleOnGestureListener() {
            private static final int SWIPE_MIN = 80;
            private static final int SWIPE_VEL = 100;

            @Override
            public boolean onDown(MotionEvent e) {
                return true;
            }

            @Override
            public boolean onFling(MotionEvent e1, MotionEvent e2, float velocityX, float velocityY) {
                if (locked || e1 == null || e2 == null) {
                    return false;
                }
                float dx = e2.getX() - e1.getX();
                float dy = e2.getY() - e1.getY();
                if (Math.abs(dx) > Math.abs(dy) && Math.abs(dx) > SWIPE_MIN && Math.abs(velocityX) > SWIPE_VEL) {
                    if (dx > 0) {
                        switchSource(-1, true);
                    } else {
                        switchSource(1, true);
                    }
                    return true;
                }
                return false;
            }

            @Override
            public boolean onScroll(MotionEvent e1, MotionEvent e2, float distanceX, float distanceY) {
                if (locked || e1 == null || e2 == null) {
                    return false;
                }
                float dx = Math.abs(e2.getX() - e1.getX());
                float dy = e1.getY() - e2.getY();
                if (dx > Math.abs(dy) || Math.abs(dy) < 8) {
                    return false;
                }
                int width = playerView.getWidth() > 0 ? playerView.getWidth() : getResources().getDisplayMetrics().widthPixels;
                if (e1.getX() < width * 0.35f) {
                    adjustBrightness(dy > 0 ? 0.03f : -0.03f);
                    return true;
                }
                if (e1.getX() > width * 0.65f) {
                    adjustVolume(dy > 0 ? 1 : -1);
                    return true;
                }
                return false;
            }

            @Override
            public boolean onSingleTapConfirmed(MotionEvent e) {
                if (locked) {
                    showFloatingButtonsTemporarily();
                    return true;
                }
                showFloatingButtonsTemporarily();
                if (player != null) {
                    if (player.isPlaying()) {
                        player.pause();
                    } else {
                        player.play();
                    }
                }
                return true;
            }
        });

        View.OnTouchListener touchListener = (v, event) -> {
            if (panelVisible && isTouchOnPanel(event)) {
                return false;
            }
            return gestureDetector.onTouchEvent(event);
        };
        playerView.setOnTouchListener(touchListener);
        findViewById(R.id.root).setOnTouchListener(touchListener);
    }

    private boolean isTouchOnPanel(MotionEvent event) {
        if (leftPanel.getVisibility() != View.VISIBLE) {
            return false;
        }
        int[] loc = new int[2];
        leftPanel.getLocationOnScreen(loc);
        float x = event.getRawX();
        float y = event.getRawY();
        return x >= loc[0] && x <= loc[0] + leftPanel.getWidth()
                && y >= loc[1] && y <= loc[1] + leftPanel.getHeight();
    }

    private void loadBrightness() {
        try {
            int sys = Settings.System.getInt(getContentResolver(), Settings.System.SCREEN_BRIGHTNESS, 128);
            brightness = Math.max(0.05f, Math.min(1f, sys / 255f));
        } catch (Exception e) {
            brightness = 0.5f;
        }
        applyBrightness();
    }

    private void applyBrightness() {
        WindowManager.LayoutParams lp = getWindow().getAttributes();
        lp.screenBrightness = brightness;
        getWindow().setAttributes(lp);
    }

    private void adjustBrightness(float delta) {
        brightness = Math.max(0.05f, Math.min(1f, brightness + delta));
        applyBrightness();
        showIndicator(getString(R.string.brightness) + " " + (int) (brightness * 100) + "%");
    }

    private void adjustVolume(int direction) {
        if (audioManager == null) {
            return;
        }
        int max = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC);
        int cur = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC);
        int next = Math.max(0, Math.min(max, cur + direction));
        audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, next, 0);
        int pct = max == 0 ? 0 : (int) (next * 100f / max);
        showIndicator(getString(R.string.volume) + " " + pct + "%");
    }

    private void showIndicator(String text) {
        indicator.setText(text);
        indicator.setVisibility(View.VISIBLE);
        if (hideIndicatorRunnable != null) {
            mainHandler.removeCallbacks(hideIndicatorRunnable);
        }
        hideIndicatorRunnable = () -> indicator.setVisibility(View.GONE);
        mainHandler.postDelayed(hideIndicatorRunnable, 1200);
    }

    private void showChannelOsd() {
        if (channels.isEmpty() || currentIndex < 0 || currentIndex >= channels.size()) {
            return;
        }
        Channel channel = channels.get(currentIndex);
        String text = (currentIndex + 1) + "/" + channels.size() + " " + channel.name;
        if (channel.getSourceCount() > 1) {
            text += " 线路 " + (currentSourceIndex + 1) + "/" + channel.getSourceCount();
        }
        channelLabel.setText(text);
        channelLabel.setVisibility(View.VISIBLE);
        if (hideChannelLabelRunnable != null) {
            mainHandler.removeCallbacks(hideChannelLabelRunnable);
        }
        hideChannelLabelRunnable = () -> channelLabel.setVisibility(View.GONE);
        mainHandler.postDelayed(hideChannelLabelRunnable, CHANNEL_OSD_MS);
    }

    private void togglePanel() {
        panelVisible = !panelVisible;
        leftPanel.setVisibility(panelVisible ? View.VISIBLE : View.GONE);
        btnTogglePanel.setText(panelVisible ? "◀" : "▶");
        showFloatingButtonsTemporarily();
    }

    private void toggleLock() {
        locked = !locked;
        btnLock.setText(locked ? "🔒" : "🔓");
        if (locked) {
            leftPanel.setVisibility(View.GONE);
            setFloatingButtonsVisible(true);
            btnTogglePanel.setVisibility(View.GONE);
        } else {
            leftPanel.setVisibility(panelVisible ? View.VISIBLE : View.GONE);
            showFloatingButtonsTemporarily();
        }
    }

    private void setFloatingButtonsVisible(boolean visible) {
        float alpha = visible ? 1f : 0f;
        int visibility = visible ? View.VISIBLE : View.GONE;
        btnLock.setAlpha(alpha);
        btnLock.setVisibility(visibility);
        btnTogglePanel.setAlpha(alpha);
        btnTogglePanel.setVisibility(locked ? View.GONE : visibility);
    }

    private void showFloatingButtonsTemporarily() {
        cancelHideFloatingButtons();
        setFloatingButtonsVisible(true);
        scheduleHideFloatingButtons();
    }

    private void scheduleHideFloatingButtons() {
        cancelHideFloatingButtons();
        if (player == null || player.getPlaybackState() != Player.STATE_READY) {
            return;
        }
        hideFloatingButtonsRunnable = () -> setFloatingButtonsVisible(false);
        mainHandler.postDelayed(hideFloatingButtonsRunnable, FLOAT_BUTTONS_TIMEOUT_MS);
    }

    private void cancelHideFloatingButtons() {
        if (hideFloatingButtonsRunnable != null) {
            mainHandler.removeCallbacks(hideFloatingButtonsRunnable);
            hideFloatingButtonsRunnable = null;
        }
    }

    private void confirmDeleteCurrentLine() {
        if (channels.isEmpty() || currentIndex < 0 || currentIndex >= channels.size()) {
            return;
        }
        Channel channel = channels.get(currentIndex);
        if (channel.getSourceCount() == 0 || currentSourceIndex < 0 || currentSourceIndex >= channel.getSourceCount()) {
            return;
        }
        String lineLabel = channel.name + " 线路 " + (currentSourceIndex + 1);
        new AlertDialog.Builder(this)
                .setTitle("删除当前线路")
                .setMessage("确认删除 " + lineLabel + " 并自动跳到下一线路吗？")
                .setPositiveButton("删除", (dialog, which) -> deleteCurrentLineAndJump())
                .setNegativeButton("取消", null)
                .show();
    }

    private void deleteCurrentLineAndJump() {
        if (channels.isEmpty() || currentIndex < 0 || currentIndex >= channels.size()) {
            return;
        }
        Channel channel = channels.get(currentIndex);
        List<String> urls = channel.getUrls();
        if (urls.isEmpty() || currentSourceIndex < 0 || currentSourceIndex >= urls.size()) {
            return;
        }
        String currentUrl = urls.get(currentSourceIndex);
        storage.hideLine(currentUrl);

        int nextIndex = urls.size() <= 1 ? -1 : currentSourceIndex;
        channels.clear();
        channels.addAll(applyChannelLineRules(fetchChannels()));
        adapter.setData(channels);

        if (channels.isEmpty()) {
            showIndicator("线路已删除");
            return;
        }

        if (currentIndex >= channels.size()) {
            currentIndex = channels.size() - 1;
        }
        Channel updated = channels.get(currentIndex);
        if (updated.getSourceCount() <= 0) {
            playNextChannel(true);
            return;
        }
        if (nextIndex < 0) {
            currentSourceIndex = 0;
        } else if (nextIndex >= updated.getSourceCount()) {
            currentSourceIndex = 0;
        } else {
            currentSourceIndex = nextIndex;
        }
        showIndicator("已删除当前线路");
        playCurrent(true, STALL_TIMEOUT_MS);
    }

    private void loadChannels() {
        if (loading) {
            return;
        }
        loading = true;
        waitingForReady = false;
        cancelStallCheck();
        status.setText(getString(R.string.loading));
        netPool.execute(() -> {
            List<Channel> loaded = fetchChannels();
            mainHandler.post(() -> {
                loading = false;
                channels.clear();
                channels.addAll(applyChannelLineRules(loaded));
                adapter.setData(channels);
                if (channels.isEmpty()) {
                    status.setText(getString(R.string.load_failed));
                    Toast.makeText(this, getString(R.string.load_failed), Toast.LENGTH_SHORT).show();
                    return;
                }
                status.setText("已加载 " + channels.size() + " 个频道");
                currentIndex = 0;
                currentSourceIndex = 0;
                playCurrent(false, CHANNEL_SWITCH_TIMEOUT_MS);
            });
        });
    }

    private List<Channel> fetchChannels() {
        for (String url : buildSourceCandidates()) {
            try {
                String body = httpGet(url);
                if (body != null && !body.isEmpty()) {
                    List<Channel> parsed = M3UParser.parse(body);
                    if (!parsed.isEmpty()) {
                        return parsed;
                    }
                }
            } catch (Exception ignored) {
            }
        }
        return new ArrayList<>();
    }

    private List<String> buildSourceCandidates() {
        List<String> urls = new ArrayList<>();
        urls.add(activeSourceUrl);
        if (DEFAULT_SOURCE_URL.equals(activeSourceUrl)) {
            for (String mirror : DEFAULT_MIRRORS) {
                if (!urls.contains(mirror)) {
                    urls.add(mirror);
                }
            }
        }
        return urls;
    }

    private void showSourceInputDialog() {
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        int pad = dp(16);
        root.setPadding(pad, pad, pad, pad);

        EditText input = new EditText(this);
        input.setSingleLine(true);
        input.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_VARIATION_URI);
        input.setHint("输入新的 m3u 或 m3u8 地址");
        root.addView(input, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT));

        LinearLayout actions = new LinearLayout(this);
        actions.setOrientation(LinearLayout.HORIZONTAL);
        root.addView(actions, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT));

        Button addButton = new Button(this);
        addButton.setText("添加");
        actions.addView(addButton, new LinearLayout.LayoutParams(
                0,
                LinearLayout.LayoutParams.WRAP_CONTENT,
                1f));

        Button deleteButton = new Button(this);
        deleteButton.setText("删除");
        actions.addView(deleteButton, new LinearLayout.LayoutParams(
                0,
                LinearLayout.LayoutParams.WRAP_CONTENT,
                1f));

        ListView listView = new ListView(this);
        LinearLayout.LayoutParams listParams = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dp(260));
        root.addView(listView, listParams);

        List<String> dialogSources = new ArrayList<>(sourceUrls);
        ArrayAdapter<String> adapter = new ArrayAdapter<>(this, android.R.layout.simple_list_item_single_choice, dialogSources);
        listView.setChoiceMode(ListView.CHOICE_MODE_SINGLE);
        listView.setAdapter(adapter);
        int checked = dialogSources.indexOf(activeSourceUrl);
        if (checked >= 0) {
            listView.setItemChecked(checked, true);
        }

        AlertDialog dialog = new AlertDialog.Builder(this)
                .setTitle("选择直播源")
                .setView(root)
                .setNegativeButton("关闭", null)
                .create();

        final int[] selectedIndex = {checked};

        addButton.setOnClickListener(v -> {
            String url = input.getText().toString().trim();
            if (url.isEmpty()) {
                showIndicator("源地址不能为空");
                return;
            }
            if (!dialogSources.contains(url)) {
                dialogSources.add(url);
                sourceUrls.clear();
                sourceUrls.addAll(dialogSources);
                persistSourceState();
                adapter.notifyDataSetChanged();
            }
            int idx = dialogSources.indexOf(url);
            if (idx >= 0) {
                selectedIndex[0] = idx;
                listView.setItemChecked(idx, true);
            }
            input.setText("");
            selectSource(url);
        });

        deleteButton.setOnClickListener(v -> {
            int idx = listView.getCheckedItemPosition();
            if (idx == ListView.INVALID_POSITION && selectedIndex[0] >= 0 && selectedIndex[0] < dialogSources.size()) {
                idx = selectedIndex[0];
            }
            if (idx < 0 || idx >= dialogSources.size()) {
                showIndicator("请先选择要删除的源");
                return;
            }
            String target = dialogSources.get(idx);
            if (DEFAULT_SOURCE_URL.equals(target)) {
                showIndicator("默认源不能删除");
                return;
            }
            dialogSources.remove(idx);
            sourceUrls.clear();
            sourceUrls.add(DEFAULT_SOURCE_URL);
            sourceUrls.addAll(dialogSources);
            if (target.equals(activeSourceUrl)) {
                activeSourceUrl = DEFAULT_SOURCE_URL;
                persistSourceState();
                adapter.notifyDataSetChanged();
                dialog.dismiss();
                reloadActiveSource();
                return;
            }
            persistSourceState();
            adapter.notifyDataSetChanged();
            selectedIndex[0] = dialogSources.indexOf(activeSourceUrl);
            listView.clearChoices();
            if (selectedIndex[0] >= 0) {
                listView.setItemChecked(selectedIndex[0], true);
            }
        });

        listView.setOnItemClickListener((parent, view, position, id) -> {
            selectedIndex[0] = position;
            String selectedUrl = dialogSources.get(position);
            selectSource(selectedUrl);
            dialog.dismiss();
        });

        dialog.show();
        input.requestFocus();
        input.post(() -> {
            InputMethodManager imm = (InputMethodManager) getSystemService(INPUT_METHOD_SERVICE);
            if (imm != null) {
                imm.showSoftInput(input, InputMethodManager.SHOW_IMPLICIT);
            }
        });
    }

    private void selectSource(String url) {
        String clean = url == null ? "" : url.trim();
        if (clean.isEmpty()) {
            showIndicator("源地址不能为空");
            return;
        }
        if (clean.equals(activeSourceUrl)) {
            return;
        }
        activeSourceUrl = clean;
        persistSourceState();
        reloadActiveSource();
    }

    private void reloadActiveSource() {
        channels.clear();
        adapter.setData(channels);
        currentIndex = 0;
        currentSourceIndex = 0;
        if (player != null) {
            player.stop();
            player.clearMediaItems();
        }
        status.setText("正在切换源...");
        setFloatingButtonsVisible(true);
        loadChannels();
    }

    private void restoreSourceState() {
        LinkedHashSet<String> urls = new LinkedHashSet<>();
        urls.add(DEFAULT_SOURCE_URL);
        urls.addAll(storage.loadSourceUrls());
        String legacy = storage.loadCustomSourceUrl();
        if (legacy != null && !legacy.trim().isEmpty()) {
            urls.add(legacy.trim());
        }
        sourceUrls.clear();
        sourceUrls.addAll(urls);
        String selected = storage.loadSelectedSourceUrl();
        if (selected != null && !selected.trim().isEmpty()) {
            activeSourceUrl = selected.trim();
            if (!sourceUrls.contains(activeSourceUrl)) {
                sourceUrls.add(activeSourceUrl);
            }
        } else {
            activeSourceUrl = DEFAULT_SOURCE_URL;
        }
        persistSourceState();
    }

    private void persistSourceState() {
        storage.saveSourceUrls(sourceUrls);
        storage.saveSelectedSourceUrl(activeSourceUrl);
        storage.saveCustomSourceUrl(activeSourceUrl);
    }

    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }

    private String httpGet(String urlStr) throws Exception {
        HttpURLConnection conn = (HttpURLConnection) new URL(urlStr).openConnection();
        conn.setConnectTimeout(8000);
        conn.setReadTimeout(10000);
        conn.setRequestProperty("User-Agent", "Mozilla/5.0 (Linux; Android 10)");
        conn.setInstanceFollowRedirects(true);
        int code = conn.getResponseCode();
        if (code < 200 || code >= 300) {
            conn.disconnect();
            return null;
        }
        InputStream is = conn.getInputStream();
        BufferedReader br = new BufferedReader(new InputStreamReader(is, "UTF-8"));
        StringBuilder sb = new StringBuilder();
        String line;
        while ((line = br.readLine()) != null) {
            sb.append(line).append('\n');
        }
        br.close();
        conn.disconnect();
        return sb.toString();
    }

    private void scheduleStallCheck(long timeoutMs) {
        if (!waitingForReady || channels.isEmpty()) {
            return;
        }
        cancelStallCheck();
        final int token = playbackToken;
        if (!hasNetworkConnection()) {
            stallRunnable = () -> {
                if (token == playbackToken && waitingForReady) {
                    scheduleStallCheck(timeoutMs);
                }
            };
            mainHandler.postDelayed(stallRunnable, NETWORK_WAIT_RETRY_MS);
            return;
        }
        stallRunnable = () -> {
            if (token == playbackToken && waitingForReady) {
                waitingForReady = false;
                switchToNextPlayableSource("当前线路加载超时，切换下一线路", true);
            }
        };
        mainHandler.postDelayed(stallRunnable, timeoutMs);
    }

    private void scheduleSilentAudioCheck() {
        cancelSilentAudioCheck();
        if (channels.isEmpty() || currentIndex < 0 || currentIndex >= channels.size()) {
            return;
        }
        final int token = playbackToken;
        silentAudioRunnable = () -> {
            if (token != playbackToken) {
                return;
            }
            if (player == null || player.getPlaybackState() != Player.STATE_READY) {
                return;
            }
            if (hasAudioTrack()) {
                return;
            }
            switchToNextPlayableSource("当前线路无声音，切换下一线路", true);
        };
        mainHandler.postDelayed(silentAudioRunnable, STALL_TIMEOUT_MS);
    }

    private void cancelStallCheck() {
        if (stallRunnable != null) {
            mainHandler.removeCallbacks(stallRunnable);
            stallRunnable = null;
        }
    }

    private void cancelSilentAudioCheck() {
        if (silentAudioRunnable != null) {
            mainHandler.removeCallbacks(silentAudioRunnable);
            silentAudioRunnable = null;
        }
    }

    private void playCurrent(boolean showOsd, long timeoutMs) {
        if (channels.isEmpty() || currentIndex < 0 || currentIndex >= channels.size()) {
            return;
        }
        Channel channel = channels.get(currentIndex);
        if (currentSourceIndex < 0 || currentSourceIndex >= channel.getSourceCount()) {
            currentSourceIndex = 0;
        }
        String url = channel.getUrls().isEmpty() ? "" : channel.getUrls().get(currentSourceIndex);
        if (url == null || url.isEmpty()) {
            waitingForReady = false;
            showIndicator("当前频道地址无效");
            return;
        }

        adapter.setSelected(currentIndex);
        channelList.scrollToPosition(currentIndex);
        playbackToken++;
        waitingForReady = true;
        autoSwitchingSource = false;
        currentPlaybackReachedReady = false;
        pendingStallTimeoutMs = timeoutMs;
        cancelSilentAudioCheck();
        scheduleStallCheck(timeoutMs);

        try {
            player.setMediaItem(MediaItem.fromUri(Uri.parse(url)));
            player.prepare();
            player.play();
            if (showOsd) {
                showChannelOsd();
            }
            if (panelVisible && !locked && showOsd) {
                mainHandler.postDelayed(() -> {
                    if (panelVisible && !locked) {
                        togglePanel();
                    }
                }, 300);
            }
        } catch (Exception e) {
            waitingForReady = false;
            cancelStallCheck();
            switchToNextPlayableSource("当前线路播放失败，切换下一线路", true);
        }
    }

    private void playCurrent(boolean showOsd) {
        playCurrent(showOsd, CHANNEL_SWITCH_TIMEOUT_MS);
    }

    private void playNextChannel(boolean showOsd) {
        if (channels.isEmpty()) {
            return;
        }
        currentIndex = (currentIndex + 1) % channels.size();
        currentSourceIndex = 0;
        playCurrent(showOsd, CHANNEL_SWITCH_TIMEOUT_MS);
    }

    private void playPreviousChannel(boolean showOsd) {
        if (channels.isEmpty()) {
            return;
        }
        currentIndex = (currentIndex - 1 + channels.size()) % channels.size();
        currentSourceIndex = 0;
        playCurrent(showOsd, CHANNEL_SWITCH_TIMEOUT_MS);
    }

    private void switchSource(int direction, boolean showOsd) {
        if (channels.isEmpty() || currentIndex < 0 || currentIndex >= channels.size()) {
            return;
        }
        Channel channel = channels.get(currentIndex);
        if (channel.getSourceCount() <= 1) {
            showIndicator("当前频道只有一个来源");
            if (showOsd) {
                showChannelOsd();
            }
            return;
        }
        int count = channel.getSourceCount();
        currentSourceIndex = (currentSourceIndex + direction + count) % count;
        playCurrent(showOsd, STALL_TIMEOUT_MS);
    }

    private void switchToNextPlayableSource(String hint, boolean showOsd) {
        if (channels.isEmpty() || currentIndex < 0 || currentIndex >= channels.size()) {
            showIndicator(hint);
            return;
        }
        Channel channel = channels.get(currentIndex);
        int count = channel.getSourceCount();
        if (count <= 1) {
            autoSwitchingSource = false;
            showIndicator(hint);
            return;
        }
        if (autoSwitchingSource) {
            return;
        }
        autoSwitchingSource = true;
        cancelSilentAudioCheck();
        int original = currentSourceIndex;
        int next = (currentSourceIndex + 1) % count;
        if (next == original) {
            autoSwitchingSource = false;
            showIndicator(hint);
            return;
        }
        currentSourceIndex = next;
        showIndicator(hint);
        playCurrent(showOsd, STALL_TIMEOUT_MS);
    }

    private boolean hasAudioTrack() {
        return player != null && player.getCurrentTracks().isTypeSelected(C.TRACK_TYPE_AUDIO);
    }

    private List<Channel> applyChannelLineRules(List<Channel> input) {
        List<Channel> output = new ArrayList<>();
        for (Channel source : input) {
            if (source == null) {
                continue;
            }
            Channel filtered = new Channel(source.name, source.group, source.key, null);
            List<String> urls = source.getUrls();
            for (int i = 0; i < urls.size(); i++) {
                String url = urls.get(i);
                if (storage.isLineHidden(url)) {
                    continue;
                }
                if (shouldSkipChannelLine(source.key, i, url)) {
                    continue;
                }
                filtered.addUrl(url);
            }
            if (filtered.getSourceCount() > 0) {
                output.add(filtered);
            }
        }
        return output;
    }

    private boolean shouldSkipChannelLine(String key, int index, String url) {
        if ("cctv10".equals(key)) {
            return index == 0;
        }
        if ("cctv14".equals(key)) {
            return index == 0;
        }
        if ("cctv13".equals(key)) {
            return index >= 0 && index <= 2;
        }
        if ("北京".equals(key)) {
            return index == 0;
        }
        if ("湖南".equals(key)) {
            return index >= 0 && index <= 1;
        }
        return false;
    }

    private boolean hasNetworkConnection() {
        ConnectivityManager cm = (ConnectivityManager) getSystemService(Context.CONNECTIVITY_SERVICE);
        if (cm == null) {
            return false;
        }
        try {
            NetworkInfo info = cm.getActiveNetworkInfo();
            return info != null && info.isConnected();
        } catch (Exception ignored) {
            return false;
        }
    }

    @Override
    public boolean onKeyDown(int keyCode, KeyEvent event) {
        if (locked && keyCode != KeyEvent.KEYCODE_DPAD_CENTER && keyCode != KeyEvent.KEYCODE_ENTER) {
            return super.onKeyDown(keyCode, event);
        }
        if (keyCode == KeyEvent.KEYCODE_DPAD_LEFT) {
            switchSource(-1, true);
            return true;
        }
        if (keyCode == KeyEvent.KEYCODE_DPAD_RIGHT) {
            switchSource(1, true);
            return true;
        }
        if (keyCode == KeyEvent.KEYCODE_DPAD_UP) {
            playPreviousChannel(true);
            return true;
        }
        if (keyCode == KeyEvent.KEYCODE_DPAD_DOWN) {
            playNextChannel(true);
            return true;
        }
        return super.onKeyDown(keyCode, event);
    }

    @Override
    protected void onStart() {
        super.onStart();
        if (player != null) {
            player.setPlayWhenReady(true);
        }
    }

    @Override
    protected void onStop() {
        cancelStallCheck();
        cancelSilentAudioCheck();
        cancelHideFloatingButtons();
        if (player != null) {
            player.setPlayWhenReady(false);
        }
        super.onStop();
    }

    @Override
    protected void onDestroy() {
        cancelStallCheck();
        cancelSilentAudioCheck();
        cancelHideFloatingButtons();
        if (hideIndicatorRunnable != null) {
            mainHandler.removeCallbacks(hideIndicatorRunnable);
        }
        if (hideChannelLabelRunnable != null) {
            mainHandler.removeCallbacks(hideChannelLabelRunnable);
        }
        if (player != null) {
            player.release();
            player = null;
        }
        netPool.shutdownNow();
        super.onDestroy();
    }

    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        if (hasFocus) {
            hideSystemUI();
        }
    }

    private void hideSystemUI() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            getWindow().setDecorFitsSystemWindows(false);
            getWindow().getInsetsController().hide(
                    android.view.WindowInsets.Type.statusBars()
                            | android.view.WindowInsets.Type.navigationBars());
            getWindow().getInsetsController().setSystemBarsBehavior(
                    android.view.WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE);
        } else {
            View decor = getWindow().getDecorView();
            decor.setSystemUiVisibility(
                    View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                            | View.SYSTEM_UI_FLAG_FULLSCREEN
                            | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                            | View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                            | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                            | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION);
        }
    }
}
