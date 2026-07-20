package org.tvplayer.app;

import android.graphics.Color;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;

import java.util.ArrayList;
import java.util.List;

public class ChannelAdapter extends RecyclerView.Adapter<ChannelAdapter.VH> {
    public interface OnChannelClick {
        void onClick(int position);
    }

    private final List<Channel> data = new ArrayList<>();
    private int selected = -1;
    private OnChannelClick click;

    public void setOnChannelClick(OnChannelClick click) {
        this.click = click;
    }

    public void setData(List<Channel> list) {
        data.clear();
        if (list != null) {
            data.addAll(list);
        }
        notifyDataSetChanged();
    }

    public void setSelected(int index) {
        int old = selected;
        selected = index;
        if (old >= 0 && old < data.size()) {
            notifyItemChanged(old);
        }
        if (selected >= 0 && selected < data.size()) {
            notifyItemChanged(selected);
        }
    }

    public Channel getItem(int position) {
        if (position < 0 || position >= data.size()) {
            return null;
        }
        return data.get(position);
    }

    @NonNull
    @Override
    public VH onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        TextView tv = new TextView(parent.getContext());
        tv.setLayoutParams(new ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT));
        tv.setPadding(16, 18, 16, 18);
        tv.setTextColor(Color.parseColor("#E0E0E0"));
        tv.setTextSize(14);
        tv.setSingleLine(true);
        return new VH(tv);
    }

    @Override
    public void onBindViewHolder(@NonNull VH holder, int position) {
        Channel ch = data.get(position);
        holder.text.setText(ch.name);
        if (position == selected) {
            holder.text.setBackgroundColor(Color.parseColor("#094771"));
        } else {
            holder.text.setBackgroundColor(Color.TRANSPARENT);
        }
        holder.itemView.setOnClickListener(v -> {
            if (click != null) {
                click.onClick(holder.getAdapterPosition());
            }
        });
    }

    @Override
    public int getItemCount() {
        return data.size();
    }

    static class VH extends RecyclerView.ViewHolder {
        final TextView text;

        VH(@NonNull View itemView) {
            super(itemView);
            text = (TextView) itemView;
        }
    }
}
