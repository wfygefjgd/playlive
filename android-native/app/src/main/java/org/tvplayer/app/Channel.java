package org.tvplayer.app;

public class Channel {
    public final String name;
    public final String url;
    public final String group;

    public Channel(String name, String url, String group) {
        this.name = name != null ? name : "未知";
        this.url = url != null ? url : "";
        this.group = group != null ? group : "未分组";
    }
}
