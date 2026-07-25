// PlayerViewModel.swift 集成智能融合引擎的修改

// 在 PlayerViewModel 类中添加以下代码：

// MARK: - 智能融合相关

private let fusionEngine = SmartFusionEngine.shared

// 添加融合模式设置（可以通过 Settings 配置）
@Published var fusionMode: FusionMode = .smart

// 监听后台优化完成的通知
private func setupFusionObserver() {
    NotificationCenter.default.addObserver(
        forName: .channelsOptimized,
        object: nil,
        queue: .main
    ) { [weak self] notification in
        guard let self else { return }
        if let optimized = notification.object as? [Channel] {
            self.channels = self.applyRules(optimized)
            self.showIndicator("线路优化完成！")
        }
    }
}

// 修改 loadChannels 方法，使用智能融合引擎
func loadChannels(force: Bool = false, silent: Bool = false, preferActiveOnly: Bool = false) {
    Task { @MainActor in
        let candidates = buildCandidates()

        // 设置进度回调
        fusionEngine.onProgress = { [weak self] message in
            self?.bootstrapMessage = message
        }

        // 🆕 使用智能融合引擎
        let (loaded, errMsg) = await fusionEngine.smartFusion(
            sourceUrls: candidates,
            mode: fusionMode
        )

        if loaded.isEmpty {
            indicatorText = errMsg ?? "加载失败"
            isBootstrapping = false
            return
        }

        rawChannels = loaded
        let filtered = applyRules(loaded)
        storage.saveChannels(loaded)

        channels = filtered
        isBootstrapping = false

        if !silent {
            let totalLines = filtered.reduce(0) { $0 + $1.sourceCount }
            showIndicator("✨ \(filtered.count) 个频道，\(totalLines) 条线路")
        }

        if currentChannel == nil && !channels.isEmpty {
            restoreLastChannelPosition()
            playCurrent(showOSD: false, resetTried: true)
        }
    }
}

// 在 startup() 方法中添加
func startup() {
    guard !started else { return }
    started = true

    // ... 现有代码 ...

    // 🆕 设置融合引擎的观察者
    setupFusionObserver()

    // ... 现有代码 ...
}

// 添加切换融合模式的方法
func switchFusionMode(_ mode: FusionMode) {
    fusionMode = mode
    UserDefaults.standard.set(mode.rawValue, forKey: "fusionMode")
    showIndicator("已切换到 \(modeName(mode)) 模式")

    // 重新加载频道
    loadChannels(force: true, silent: false, preferActiveOnly: false)
}

private func modeName(_ mode: FusionMode) -> String {
    switch mode {
    case .fast: return "快速"
    case .balanced: return "平衡"
    case .complete: return "完整"
    case .smart: return "智能"
    }
}

// 从 UserDefaults 恢复融合模式设置
func restoreFusionMode() {
    if let saved = UserDefaults.standard.string(forKey: "fusionMode"),
       let mode = FusionMode(rawValue: saved) {
        fusionMode = mode
    }
}
