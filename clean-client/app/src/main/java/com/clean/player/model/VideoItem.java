package com.clean.player.model;

import java.util.List;

/**
 * Core playable fields from original VideoItemBean.
 * Ad fields (ad/ads/play_ads) intentionally unused.
 */
public class VideoItem {
    public String id;
    public String video_id;
    public String name;
    public String title;
    public String desc;
    public String img_x;
    public String img_y;
    public String cover;
    public String duration;
    public String play_num;
    public String like;
    public String love;
    public String comment;
    public String is_vip;
    public String is_free;
    public String pay_type;
    public String money;
    public String preview_link;
    public String link;
    public List<String> play_links;
    public List<String> links;
    public String nickname;
    public String user_id;
    public String tags;
    public String type;
    public String published_at;

    public String bestCover() {
        if (img_x != null && !img_x.isEmpty()) return img_x;
        if (img_y != null && !img_y.isEmpty()) return img_y;
        if (cover != null && !cover.isEmpty()) return cover;
        return "";
    }

    public String bestTitle() {
        if (name != null && !name.isEmpty()) return name;
        if (title != null && !title.isEmpty()) return title;
        return "未命名";
    }

    public String bestPlayUrl() {
        if (play_links != null) {
            for (String u : play_links) {
                if (u != null && !u.isEmpty()) return u;
            }
        }
        if (links != null) {
            for (String u : links) {
                if (u != null && !u.isEmpty()) return u;
            }
        }
        if (link != null && !link.isEmpty()) return link;
        if (preview_link != null && !preview_link.isEmpty()) return preview_link;
        return "";
    }

    public String idOrVideoId() {
        if (id != null && !id.isEmpty()) return id;
        return video_id == null ? "" : video_id;
    }
}
