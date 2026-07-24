package com.clean.player.model;

import java.util.List;

/**
 * Core fields from original SystemInfoBean, ads stripped from client usage.
 */
public class SystemInfo {
    public String can_use;
    public String error_msg;
    public String version;
    public String min_version;
    public String version_description;
    public String download_url;
    public String cdn_header;
    public String img_key;
    public String site_url;
    public String chat_url;
    public String service_email;
    public String service_link;
    public String upload_url;
    public String upload_file_url;
    public String upload_image_url;
    public String upload_token;
    public String welcome_msg;
    public String total_video;
    public TokenBean token;
    public List<HomeTab> tabs;
    public List<HomeTab> short_tabs;
    public List<HomeTab> normal_video_nav;

    public static class HomeTab {
        public String id;
        public String name;
        public String title;
        public String type;
        public String api;
        public String key;
        public String url;
    }
}
