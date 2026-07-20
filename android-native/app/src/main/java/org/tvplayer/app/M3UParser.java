package org.tvplayer.app;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public class M3UParser {
    private static final Pattern GROUP = Pattern.compile("group-title=\"([^\"]*)\"");
    private static final Pattern NAME = Pattern.compile(",(.+?)$");
    private static final Pattern CCTV_PATTERN = Pattern.compile("cctv\\s*[-_ ]*0*([1-9]\\d*)(k|\\+)?", Pattern.CASE_INSENSITIVE);
    private static final Pattern TRAILING_NOISE = Pattern.compile("(fhd|uhd|hd|sd|4k|8k|1080p|720p|576p|50fps|60fps|h264|h265|hevc|hdr|高清|超清|标清|蓝光|流畅|高码|高帧|测试|备用\\d*|线路\\d+|源\\d+|直播|在线|综合|频道|央视|卫视|中文|台)$", Pattern.CASE_INSENSITIVE);

    public static List<Channel> parse(String text) {
        if (text == null || text.isEmpty()) {
            return new ArrayList<>();
        }
        Map<String, Channel> channels = new LinkedHashMap<>();
        String[] lines = text.split("\\r?\\n");
        String pendingName = null;
        String pendingGroup = "未分组";

        for (String raw : lines) {
            String line = raw.trim();
            if (line.startsWith("#EXTINF:")) {
                Matcher gm = GROUP.matcher(line);
                pendingGroup = gm.find() ? gm.group(1) : "未分组";
                Matcher nm = NAME.matcher(line);
                pendingName = nm.find() ? nm.group(1).trim() : "未知";
            } else if (!line.isEmpty() && !line.startsWith("#") && pendingName != null) {
                String displayName = normalizeDisplayName(pendingName);
                String key = normalizeName(displayName);
                Channel channel = channels.get(key);
                if (channel == null) {
                    channel = new Channel(displayName, pendingGroup, key, null);
                    channels.put(key, channel);
                }
                channel.addUrl(line);
                pendingName = null;
                pendingGroup = "未分组";
            }
        }
        return new ArrayList<>(channels.values());
    }

    public static String normalizeName(String name) {
        if (name == null) {
            return "";
        }
        String working = name.trim().toLowerCase(Locale.ROOT);
        Matcher cctv = CCTV_PATTERN.matcher(working);
        if (cctv.find()) {
            String suffix = cctv.group(2) != null ? cctv.group(2).toUpperCase(Locale.ROOT) : "";
            return "cctv" + Integer.parseInt(cctv.group(1)) + suffix;
        }
        working = working.replaceAll("[\\s\\-—_·.．,，、/\\\\|()（）\\[\\]【】:+]+", "");
        working = working.replace("中央", "cctv");
        working = working.replace("央视", "cctv");
        working = working.replace("高清", "");
        working = working.replace("超清", "");
        working = working.replace("蓝光", "");
        working = working.replace("流畅", "");
        working = working.replace("频道", "");
        working = working.replace("直播", "");
        working = working.replace("在线", "");
        working = working.replaceAll("(测试|试看|备份|备用|线路|源)+", "");
        working = working.replaceAll("(?:第)?0*([1-9]\\d*)台$", "$1");
        working = stripTrailingNoise(working);
        return working;
    }

    public static String normalizeDisplayName(String rawName) {
        String clean = rawName == null ? "未知" : rawName.trim();
        Matcher cctv = CCTV_PATTERN.matcher(clean);
        if (cctv.find()) {
            String suffix = cctv.group(2) != null ? cctv.group(2).toUpperCase(Locale.ROOT) : "";
            return "CCTV-" + Integer.parseInt(cctv.group(1)) + suffix;
        }
        clean = clean.replaceAll("\\s+", " ");
        clean = clean.replaceAll("(?i)(高清|超清|蓝光|流畅|频道|直播|在线|测试|备用\\d*|线路\\d+|源\\d+)$", "").trim();
        return clean.isEmpty() ? "未知" : clean;
    }

    private static String stripTrailingNoise(String value) {
        String working = value;
        while (true) {
            Matcher matcher = TRAILING_NOISE.matcher(working);
            if (!matcher.find()) {
                break;
            }
            working = working.substring(0, matcher.start());
        }
        return working;
    }
}
