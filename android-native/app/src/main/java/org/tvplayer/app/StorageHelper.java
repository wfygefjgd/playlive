package org.tvplayer.app;

import android.content.Context;
import android.content.SharedPreferences;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

public class StorageHelper {
    private static final String PREF = "tvplayer";
    private static final String KEY_CACHE = "channels_cache";
    private static final String KEY_FAV = "favorites";
    private static final String KEY_HIDDEN = "hidden";

    private final SharedPreferences prefs;

    public StorageHelper(Context context) {
        prefs = context.getSharedPreferences(PREF, Context.MODE_PRIVATE);
    }

    public void saveChannels(List<Channel> channels) {
        try {
            JSONArray arr = new JSONArray();
            for (Channel c : channels) {
                JSONObject o = new JSONObject();
                o.put("name", c.name);
                o.put("url", c.url);
                o.put("group", c.group);
                arr.put(o);
            }
            prefs.edit().putString(KEY_CACHE, arr.toString()).apply();
        } catch (Exception ignored) {
        }
    }

    public List<Channel> loadChannels() {
        List<Channel> list = new ArrayList<>();
        try {
            String raw = prefs.getString(KEY_CACHE, null);
            if (raw == null || raw.isEmpty()) {
                return list;
            }
            JSONArray arr = new JSONArray(raw);
            for (int i = 0; i < arr.length(); i++) {
                JSONObject o = arr.getJSONObject(i);
                list.add(new Channel(
                        o.optString("name", "未知"),
                        o.optString("url", ""),
                        o.optString("group", "未分组")
                ));
            }
        } catch (Exception ignored) {
        }
        return list;
    }

    public Set<String> loadFavorites() {
        return new HashSet<>(prefs.getStringSet(KEY_FAV, new HashSet<String>()));
    }

    public void saveFavorites(Set<String> urls) {
        prefs.edit().putStringSet(KEY_FAV, new HashSet<>(urls)).apply();
    }

    public Set<String> loadHidden() {
        return new HashSet<>(prefs.getStringSet(KEY_HIDDEN, new HashSet<String>()));
    }

    public void saveHidden(Set<String> urls) {
        prefs.edit().putStringSet(KEY_HIDDEN, new HashSet<>(urls)).apply();
    }

    public void toggleFavorite(String url) {
        Set<String> fav = loadFavorites();
        if (fav.contains(url)) {
            fav.remove(url);
        } else {
            fav.add(url);
        }
        saveFavorites(fav);
    }

    public boolean isFavorite(String url) {
        return loadFavorites().contains(url);
    }

    public boolean isHidden(String url) {
        return loadHidden().contains(url);
    }
}
