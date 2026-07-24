package com.clean.player.ui;

import android.content.Intent;
import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;

import com.clean.player.R;
import com.clean.player.net.LineConfig;
import com.clean.player.util.DeviceUtil;
import com.clean.player.util.Prefs;

public class MineFragment extends Fragment {
    @Nullable
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, @Nullable ViewGroup container,
                             @Nullable Bundle savedInstanceState) {
        return inflater.inflate(R.layout.fragment_mine, container, false);
    }

    @Override
    public void onViewCreated(@NonNull View view, @Nullable Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);
        TextView tvName = view.findViewById(R.id.tvName);
        TextView tvUid = view.findViewById(R.id.tvUid);
        TextView tvLine = view.findViewById(R.id.tvLine);

        String token = Prefs.get(Prefs.USER_TOKEN);
        tvName.setText(token == null || token.isEmpty() ? "游客模式" : "已登录");
        tvUid.setText("设备: " + DeviceUtil.deviceId());
        tvLine.setText("当前线路:\n" + LineConfig.current());

        view.setOnLongClickListener(v -> {
            startActivity(new Intent(requireContext(), SearchActivity.class));
            return true;
        });
    }
}
