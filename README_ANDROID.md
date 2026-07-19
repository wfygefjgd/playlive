# TVPlayer Android

Kivy 版电视直播播放器，兼容 Android 4.4 - 13

## 功能

- 左右滑动切换频道
- 左侧上下滑动调亮度
- 右侧上下滑动调音量
- 锁定按钮（左下角）
- 隐藏/显示左侧面板（右上角）
- 频道缓存，断网可用
- 收藏、隐藏频道

## 构建 APK

### Linux / WSL

```bash
# 安装依赖
sudo apt install python3-pip git openjdk-17-jdk zip unzip
pip install buildozer cython

# 构建
cd TVPlayer
buildozer android debug
```

### 输出文件

`bin/TVPlayer-1.0.0-*-debug.apk`

### 直接安装

APK 在手机侧载安装即可，需要开启"允许安装未知来源应用"。
