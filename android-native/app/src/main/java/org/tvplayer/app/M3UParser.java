package org.tvplayer.app;

import java.util.ArrayList;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public class M3UParser {
    private static final Pattern GROUP = Pattern.compile("group-title=\"([^\"]*)\"");
    private static final Pattern NAME = Pattern.compile(",(.+?)$");

    public static List<Channel> parse(String text) {
        List<Channel> channels = new ArrayList<>();
        if (text == null || text.isEmpty()) {
            return channels;
        }
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
                channels.add(new Channel(pendingName, line, pendingGroup));
                pendingName = null;
                pendingGroup = "未分组";
            }
        }
        return channels;
    }
}
