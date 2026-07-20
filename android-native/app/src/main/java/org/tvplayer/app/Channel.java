package org.tvplayer.app;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

public class Channel {
    public final String name;
    public final String group;
    public final String key;
    private final List<String> urls;

    public Channel(String name, String url, String group) {
        this(name, group, M3UParser.normalizeName(name), new ArrayList<String>());
        addUrl(url);
    }

    public Channel(String name, String group, String key, List<String> urls) {
        this.name = name != null && !name.trim().isEmpty() ? name.trim() : "未知";
        this.group = group != null && !group.trim().isEmpty() ? group.trim() : "未分组";
        this.key = key != null && !key.trim().isEmpty() ? key.trim() : M3UParser.normalizeName(this.name);
        this.urls = new ArrayList<>();
        if (urls != null) {
            for (String url : urls) {
                addUrl(url);
            }
        }
    }

    public void addUrl(String url) {
        if (url == null) {
            return;
        }
        String clean = url.trim();
        if (clean.isEmpty() || urls.contains(clean)) {
            return;
        }
        urls.add(clean);
    }

    public List<String> getUrls() {
        return Collections.unmodifiableList(urls);
    }

    public String getPrimaryUrl() {
        return urls.isEmpty() ? "" : urls.get(0);
    }

    public int getSourceCount() {
        return urls.size();
    }

    public String getStorageKey() {
        return key;
    }
}
