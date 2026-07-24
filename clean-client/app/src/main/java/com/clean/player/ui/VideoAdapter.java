package com.clean.player.ui;

import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageView;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;

import com.bumptech.glide.Glide;
import com.clean.player.R;
import com.clean.player.model.VideoItem;

import java.util.ArrayList;
import java.util.List;

public class VideoAdapter extends RecyclerView.Adapter<VideoAdapter.VH> {
    public interface OnClick {
        void onClick(VideoItem item);
    }

    private final List<VideoItem> data = new ArrayList<>();
    private final OnClick onClick;

    public VideoAdapter(OnClick onClick) {
        this.onClick = onClick;
    }

    public void setItems(List<VideoItem> items) {
        data.clear();
        if (items != null) data.addAll(items);
        notifyDataSetChanged();
    }

    @NonNull
    @Override
    public VH onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        View v = LayoutInflater.from(parent.getContext()).inflate(R.layout.item_video, parent, false);
        return new VH(v);
    }

    @Override
    public void onBindViewHolder(@NonNull VH h, int position) {
        VideoItem item = data.get(position);
        h.tvTitle.setText(item.bestTitle());
        String meta = "";
        if (item.duration != null) meta += item.duration + "  ";
        if (item.play_num != null) meta += "播放 " + item.play_num;
        h.tvMeta.setText(meta.trim());
        String cover = item.bestCover();
        if (cover != null && !cover.isEmpty()) {
            Glide.with(h.ivCover).load(cover).centerCrop().into(h.ivCover);
        } else {
            h.ivCover.setImageDrawable(null);
        }
        h.itemView.setOnClickListener(v -> {
            if (onClick != null) onClick.onClick(item);
        });
    }

    @Override
    public int getItemCount() {
        return data.size();
    }

    static class VH extends RecyclerView.ViewHolder {
        ImageView ivCover;
        TextView tvTitle;
        TextView tvMeta;

        VH(@NonNull View itemView) {
            super(itemView);
            ivCover = itemView.findViewById(R.id.ivCover);
            tvTitle = itemView.findViewById(R.id.tvTitle);
            tvMeta = itemView.findViewById(R.id.tvMeta);
        }
    }
}
