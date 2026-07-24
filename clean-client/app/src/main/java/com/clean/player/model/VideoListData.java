package com.clean.player.model;

import java.util.List;

public class VideoListData {
    public List<VideoItem> list;
    public List<VideoItem> data;
    public List<VideoItem> videos;
    public int total;
    public int page;
    public int page_size;

    public List<VideoItem> items() {
        if (list != null) return list;
        if (data != null) return data;
        return videos;
    }
}
