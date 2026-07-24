package com.clean.player.model;

public class ApiResponse<T> {
    public int code;
    public String msg;
    public String message;
    public T data;
    public String status;

    public boolean ok() {
        return code == 0 || code == 200 || "success".equalsIgnoreCase(status)
                || "ok".equalsIgnoreCase(status);
    }

    public String tip() {
        if (msg != null && !msg.isEmpty()) return msg;
        if (message != null && !message.isEmpty()) return message;
        return "请求失败";
    }
}
