package com.clean.player.ui;

import android.os.Bundle;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AppCompatActivity;
import androidx.fragment.app.Fragment;
import androidx.viewpager2.adapter.FragmentStateAdapter;
import androidx.viewpager2.widget.ViewPager2;

import com.clean.player.R;
import com.google.android.material.bottomnavigation.BottomNavigationView;

public class MainActivity extends AppCompatActivity {
    private ViewPager2 viewPager;

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        viewPager = findViewById(R.id.viewPager);
        BottomNavigationView nav = findViewById(R.id.bottomNav);

        viewPager.setUserInputEnabled(false);
        viewPager.setAdapter(new FragmentStateAdapter(this) {
            @NonNull
            @Override
            public Fragment createFragment(int position) {
                if (position == 0) {
                    return VideoListFragment.home();
                } else if (position == 1) {
                    return VideoListFragment.shorts();
                } else {
                    return new MineFragment();
                }
            }

            @Override
            public int getItemCount() {
                return 3;
            }
        });

        nav.setOnItemSelectedListener(item -> {
            int id = item.getItemId();
            if (id == R.id.nav_home) {
                viewPager.setCurrentItem(0, false);
                return true;
            } else if (id == R.id.nav_short) {
                viewPager.setCurrentItem(1, false);
                return true;
            } else if (id == R.id.nav_mine) {
                viewPager.setCurrentItem(2, false);
                return true;
            }
            return false;
        });
    }
}
