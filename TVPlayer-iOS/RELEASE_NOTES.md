# TVPlayer iOS v1.4.6 更新说明

## 🎉 v1.4.6 更新说明

### 🔧 核心引擎优化
- 重构 PlayerEngine：统一 Task 管理，避免任务泄漏
- 新增静音检测：3秒后自动检测无声音轨并切线
- 卡顿检测优化：使用 Date 追踪进度，避免主线程卡住误判
- 线程安全：PlayerEngine 标记 @MainActor，编译期保证主线程访问

### 🌐 网络优化
- 全候选竞速：所有直播源并发请求，取最快返回结果
- 断网自动重试：监听网络恢复，自动重新加载频道
- 网络类型感知：区分 WiFi/蜂窝网络，蜂窝时提示用户
- 指数退避重试：失败后 1s/2s/4s 递增重试

### 💾 存储优化
- 线程安全：StorageService 使用 DispatchQueue + barrier
- 元数据缓存：记录版本/数量/更新时间，快速判断缓存状态
- 数据迁移：版本号机制，支持未来结构变更
- Channel 模型改为 struct 值类型，更安全

### 🎮 交互优化
- 数字键选台：iPad 键盘 0-9 输入频道号，2秒超时自动确认
- 键盘快捷键：方向键切台/切线，空格暂停/播放
- 双击画面：切换频道面板显隐
- 触觉反馈：按键/长按震动反馈
- 搜索框：FocusState + 清除按钮

### 🎨 UI 动画
- OSD 渐入渐出 + 缩放动画
- 指示器弹性动画
- 悬浮按钮显隐过渡动画

### 📱 后台播放
- 添加 UIBackgroundModes audio
- Audio Session 配置：playback + moviePlayback + AirPlay
- 音频中断恢复：来电结束后自动恢复播放
- 锁屏远程控制：播放/暂停/上一台/下一台

### 🔒 合规修复
- 音量控制改用公开 API，避免私有 API 审核风险
- Info.plist 添加后台音频声明

### 🐛 Bug 修复
- 修复 hasActiveAudioTrack 逻辑错误（判断反了）
- 修复 isStalled 多线程数据竞争
- 修复 ContentView onAppear 多余 async dispatch
- 修复 OrderedDictionary O(n) 删除性能问题

---

**安装方式：** 下载 TVPlayer.ipa → 用 Sideloadly/AltStore 侧载

**系统要求：** iOS 15.0+

**注意：** 免费 Apple ID 签名每 7 天需重签一次
