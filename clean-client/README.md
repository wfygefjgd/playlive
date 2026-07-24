# CleanPlayer

从桌面 `1.apk` 逆向后重写的**无广告精简客户端骨架**。

## 已完成

- 线路列表 / 启动测速 (`xl/p`)
- 系统初始化接口 (`yh/xx`)
- 首页 / 短视频列表 / 搜索 / 播放
- 去掉广告位、悬浮广告、应用商店推广、图标伪装
- API 路径与数据模型见 `API.md`

## 工程位置

`C:\Users\96335\Desktop\TVPlayer\clean-client`

## 构建

用 Android Studio 打开 `clean-client`，或：

```bat
cd clean-client
gradlew.bat assembleDebug
```

## 重要限制

原版请求体很可能经 `libsecurity.so` 的 **AES** 封装。  
当前客户端发的是**明文 JSON**。若接口 4xx/空数据，需要继续：

1. Frida hook `nativeGetAesKey` + 加密函数，或  
2. 逆向 `libsecurity.so` 把 AES key/算法补进 `net` 包

## 使用

1. 启动自动测线路并拉 systemInfo  
2. 底部：首页 / 短视频 / 我的  
3. 在「我的」页**长按**进入搜索  
4. 点击条目用 ExoPlayer 播放（自动带 `cdn_header` 作 Referer）
