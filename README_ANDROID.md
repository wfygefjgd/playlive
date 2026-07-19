# TVPlayer Android

兼容 **Android 4.4 (API 19) ~ Android 13 (API 33)** 的电视直播播放器。

## 两种实现

### 1. 原生 Android（推荐）

目录：`android-native/`

- Java + ExoPlayer 2.14
- minSdk 19 / targetSdk 33
- 左右滑动切台
- 左侧上下滑动：亮度
- 右侧上下滑动：音量
- 左上角：隐藏/显示频道面板
- 左下角：锁定（禁止操作，锁定时仍可点解锁）
- 频道缓存 / 收藏 / 搜索

#### 构建 APK（Android Studio 或命令行）

```bash
cd android-native
# 需要 Android SDK + JDK 11+
./gradlew assembleDebug
# 输出: app/build/outputs/apk/debug/app-debug.apk
```

Windows:

```bat
cd android-native
gradlew.bat assembleDebug
```

### 2. Kivy 版（Python）

文件：`android_main.py` + `main.py` + `buildozer.spec`

- 同样手势逻辑
- 需 Linux / WSL + Buildozer 打包

```bash
pip install buildozer cython
buildozer android debug
# 输出: bin/tvplayer-1.0.0-*-debug.apk
```

## 手势说明

| 操作 | 功能 |
|------|------|
| 左右滑动 | 上/下一频道 |
| 左侧上下滑 | 亮度 |
| 右侧上下滑 | 音量 |
| 单击画面 | 暂停/播放 |
| 左上角按钮 | 隐藏/显示列表 |
| 左下角按钮 | 锁定/解锁 |
| 长按频道 | 收藏/取消收藏 |

## 源与 Windows 版一致

- best-fan / TVBox / vbskycn / fanmingming
- 支持 GitHub 镜像加速
- 有缓存时不自动联网，点刷新才更新
