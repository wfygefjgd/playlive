package com.clean.player;

import android.app.Application;

import com.clean.player.net.NetManager;
import com.clean.player.util.Prefs;

public class App extends Application {
    private static App instance;

    @Override
    public void onCreate() {
        super.onCreate();
        instance = this;
        Prefs.init(this);
        NetManager.init();
    }

    public static App get() {
        return instance;
    }
}
