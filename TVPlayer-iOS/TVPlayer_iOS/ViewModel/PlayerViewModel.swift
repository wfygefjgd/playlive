import SwiftUI
import AVKit

let DEFAULT_SOURCE_URL = "https://ghproxy.net/https://raw.githubusercontent.com/best-fan/iptv-sources/master/cn_all_status.m3u8"

private let CHANNEL_OSD_MS: UInt64 = 2_500_000_000
private let FLOAT_HIDE_MS: UInt64 = 2_500_000_000
private let INDICATOR_MS: UInt64 = 1_200_000_000
/// 自动切线冷却
private let AUTO_SWITCH_COOLDOWN_NS: UInt64 = 4_000_000_000
/// 自动切线冷却（方案 A）
private let AUTO_SWITCH_COOLDOWN_NS: UInt64 = 4_000_000_000

let PRESET_SOURCES: [(name: String, url: String)] = [
    ("默认源", DEFAULT_SOURCE_URL),
    ("best-fan 全量", "https://ghproxy.net/https://raw.githubusercontent.com/best-fan/iptv-sources/main/cn_all.m3u8"),
    ("TVBox", "https://ghfast.top/raw.githubusercontent.com/Supprise0901/TVBox_live/main/live.txt"),
    ("vbskycn", "https://raw.githubusercontent.com/vbskycn/iptv/master/tv/tv.m3u"),
    ("fanmingming", "https://raw.githubusercontent.com/fanmingming/live/main/tv/m3u/ipv6.m3u"),
]

@MainActor
final class PlayerViewModel: ObservableObject {
    @Published var channels: [Channel] = []
    @Published var currentIndex = 0
    @Published var currentSourceIndex = 0
    @Published var panelVisible = false
    @Published var locked = false
    @Published var showSourceSheet = false
    @Published var showDeleteAlert = false
    @Published var channelOSD: String = ""
    @Published var indicatorText: String = ""
    @Published var showFloatOverlay = false

    let player = PlayerEngine()
    private let storage = StorageService()
    private var rawChannels: [Channel] = []
    var sourceUrls: [String] = []
    var activeSourceUrl = DEFAULT_SOURCE_URL
    private var autoSwitching = false
    private var autoSwitchCooldown = false
    private var started = false
    /// 当前频道已自动试过的线路下标（一轮试完后停止）
    private var triedLineIndices = Set<Int>()
    private var osdTask: Task<Void, Never>?
    private var indTask: Task<Void, Never>?
    private var floatTask: Task<Void, Never>?
    private var cooldownTask: Task<Void, Never>?

    func startup() {
        guard !started else { return }
        started = true

        player.onReady = { [weak self] in
            Task { @MainActor in self?.onPlayerReady() }
        }
        player.onError = { [weak self] in
            Task { @MainActor in self?.onPlayerError() }
        }
        player.onStartupTimeout = { [weak self] in
            Task { @MainActor in self?.onStartupTimeout() }
        }
        player.onPlaybackStall = { [weak self] in
            Task { @MainActor in self?.onPlaybackStall() }
        }

        restoreSources()
        let cached = applyRules(storage.loadChannels())
        if !cached.isEmpty {
            channels = cached
            currentIndex = 0
            currentSourceIndex = 0
            playCurrent(showOSD: false)
        }
        loadChannels(force: cached.isEmpty)
    }

    // MARK: - Sources

    func restoreSources() {
        var urls = OrderedDictionary<String, Bool>()
        for p in PRESET_SOURCES { urls[p.url] = true }
        for u in storage.loadSourceUrls() {
            let clean = u.trimmingCharacters(in: .whitespaces)
            if !clean.isEmpty { urls[clean] = true }
        }
        sourceUrls = urls.keys
        let selected = storage.loadSelectedSourceUrl().trimmingCharacters(in: .whitespaces)
        if !selected.isEmpty {
            activeSourceUrl = selected
            if !sourceUrls.contains(selected) { sourceUrls.append(selected) }
        } else {
            activeSourceUrl = DEFAULT_SOURCE_URL
        }
        persistSources()
    }

    func persistSources() {
        storage.saveSourceUrls(sourceUrls)
        storage.saveSelectedSourceUrl(activeSourceUrl)
        storage.saveCustomSourceUrl(activeSourceUrl)
    }

    func selectSource(_ url: String) {
        let clean = url.trimmingCharacters(in: .whitespaces)
        guard !clean.isEmpty, clean != activeSourceUrl else { return }
        activeSourceUrl = clean
        if !sourceUrls.contains(clean) { sourceUrls.append(clean) }
        persistSources()
        reloadActiveSource()
    }

    func reloadActiveSource() {
        channels = []
        rawChannels = []
        currentIndex = 0
        currentSourceIndex = 0
        player.stop()
        indicatorText = "正在切换源..."
        showFloat()
        loadChannels(force: true)
    }

    func deleteSourceUrl(_ url: String) {
        guard url != DEFAULT_SOURCE_URL else { return }
        sourceUrls.removeAll { $0 == url }
        storage.removeSourceUrl(url)
        if activeSourceUrl == url {
            activeSourceUrl = DEFAULT_SOURCE_URL
            if !sourceUrls.contains(DEFAULT_SOURCE_URL) {
                sourceUrls.append(DEFAULT_SOURCE_URL)
            }
            persistSources()
            reloadActiveSource()
        } else {
            persistSources()
        }
    }

    // MARK: - Load

    func loadChannels(force: Bool = true) {
        guard !player.isReady || force else { return }
        indicatorText = "加载中..."
        let urls = buildCandidates()
        Task {
            let loaded = await NetworkService.shared.fetchWithCandidates(urls: urls)
            await MainActor.run { onChannelsLoaded(loaded) }
        }
    }

    private func onChannelsLoaded(_ loaded: [Channel]) {
        guard !loaded.isEmpty else {
            showIndicator(channels.isEmpty ? "加载失败" : "刷新失败")
            return
        }
        rawChannels = loaded.map { Channel(name: $0.name, group: $0.group, key: $0.key, urls: $0.urls) }
        channels = applyRules(rawChannels)
        guard !channels.isEmpty else {
            showIndicator("加载失败")
            return
        }
        storage.saveChannels(loaded)
        showIndicator("已加载 \(channels.count) 个频道")
        currentIndex = min(currentIndex, channels.count - 1)
        currentSourceIndex = 0
        playCurrent(showOSD: false)
    }

    func buildCandidates() -> [String] {
        var candidates = [activeSourceUrl]
        for url in sourceUrls where url != activeSourceUrl {
            candidates.append(url)
        }
        return candidates
    }

    // MARK: - Rules

    func applyRules(_ input: [Channel]) -> [Channel] {
        input.compactMap { src in
            let filtered = Channel(name: src.name, group: src.group, key: src.key)
            for (i, url) in src.urls.enumerated() {
                if storage.isLineHidden(url) { continue }
                if shouldSkipLine(key: src.key, index: i) { continue }
                filtered.addUrl(url)
            }
            return filtered.sourceCount > 0 ? filtered : nil
        }
    }

    private func shouldSkipLine(key: String, index: Int) -> Bool {
        switch key {
        case "cctv10", "cctv14", "北京": return index == 0
        case "cctv13": return (0...2).contains(index)
        case "湖南": return (0...1).contains(index)
        default: return false
        }
    }

    // MARK: - Current

    var currentChannel: Channel? {
        guard !channels.isEmpty, channels.indices.contains(currentIndex) else { return nil }
        return channels[currentIndex]
    }

    var currentUrl: String? {
        guard let ch = currentChannel, ch.urls.indices.contains(currentSourceIndex) else { return nil }
        return ch.urls[currentSourceIndex]
    }

    // MARK: - Play

    func playCurrent(showOSD: Bool = true, resetTried: Bool = false) {
        guard currentChannel != nil, let url = currentUrl, let u = URL(string: url) else {
            showIndicator("当前频道地址无效")
            return
        }
        if resetTried {
            triedLineIndices.removeAll()
        }
        triedLineIndices.insert(currentSourceIndex)
        autoSwitching = false
        player.play(url: u)
        if showOSD { showChannelOSD() }
        showFloat()
    }

    private func onPlayerReady() {
        autoSwitching = false
        scheduleHideFloat()
        if !indicatorText.isEmpty {
            showIndicator("")
        }
    }

    private func onPlayerError() {
        autoSwitchLine(hint: "线路失败，切换下一线路")
    }

    private func onStartupTimeout() {
        autoSwitchLine(hint: "线路超时，切换下一线路")
    }

    private func onPlaybackStall() {
        autoSwitchLine(hint: "网络卡顿，切换下一线路")
    }

    /// 方案 A：自动切线（冷却 + 同频道一轮试完即停）
    private func autoSwitchLine(hint: String) {
        guard !locked, !autoSwitching, !autoSwitchCooldown else { return }
        guard let ch = currentChannel, ch.sourceCount > 1 else {
            showIndicator(hint)
            return
        }
        // 找尚未试过的下一线路
        var nxt = (currentSourceIndex + 1) % ch.sourceCount
        var scanned = 0
        while triedLineIndices.contains(nxt), scanned < ch.sourceCount {
            nxt = (nxt + 1) % ch.sourceCount
            scanned += 1
        }
        if scanned >= ch.sourceCount || triedLineIndices.count >= ch.sourceCount {
            autoSwitching = false
            showIndicator("当前频道线路均不可用")
            return
        }
        autoSwitching = true
        autoSwitchCooldown = true
        currentSourceIndex = nxt
        showIndicator(hint)
        playCurrent(showOSD: true, resetTried: false)
        startCooldown()
    }

    private func startCooldown() {
        cooldownTask?.cancel()
        cooldownTask = Task {
            try? await Task.sleep(nanoseconds: AUTO_SWITCH_COOLDOWN_NS)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                autoSwitchCooldown = false
                autoSwitching = false
            }
        }
    }

    // MARK: - Navigation

    func nextChannel() {
        guard !locked, !channels.isEmpty else { return }
        currentIndex = (currentIndex + 1) % channels.count
        currentSourceIndex = 0
        panelVisible = false
        triedLineIndices.removeAll()
        autoSwitchCooldown = false
        playCurrent(resetTried: true)
    }

    func prevChannel() {
        guard !locked, !channels.isEmpty else { return }
        currentIndex = (currentIndex - 1 + channels.count) % channels.count
        currentSourceIndex = 0
        panelVisible = false
        triedLineIndices.removeAll()
        autoSwitchCooldown = false
        playCurrent(resetTried: true)
    }

    func switchSource(direction: Int) {
        guard !locked, let ch = currentChannel, ch.sourceCount > 1 else {
            if let ch = currentChannel, ch.sourceCount <= 1 {
                showIndicator("当前频道只有一个来源")
                showChannelOSD()
            }
            return
        }
        // 手动切线：重置已试集合与冷却
        triedLineIndices.removeAll()
        autoSwitchCooldown = false
        currentSourceIndex = (currentSourceIndex + direction + ch.sourceCount) % ch.sourceCount
        playCurrent(resetTried: true)
    }

    func switchNextLine(hint: String) {
        autoSwitchLine(hint: hint)
    }

    // MARK: - OSD / Indicator

    func showChannelOSD() {
        guard let ch = currentChannel else { return }
        var text = "\(currentIndex + 1)/\(channels.count) \(ch.name)"
        if ch.sourceCount > 1 {
            text += "  线路 \(currentSourceIndex + 1)/\(ch.sourceCount)"
        }
        channelOSD = text
        osdTask?.cancel()
        osdTask = Task {
            try? await Task.sleep(nanoseconds: CHANNEL_OSD_MS)
            guard !Task.isCancelled else { return }
            await MainActor.run { channelOSD = "" }
        }
    }

    func showIndicator(_ text: String) {
        indicatorText = text
        indTask?.cancel()
        guard !text.isEmpty else { return }
        indTask = Task {
            try? await Task.sleep(nanoseconds: INDICATOR_MS)
            guard !Task.isCancelled else { return }
            await MainActor.run { indicatorText = "" }
        }
    }

    // MARK: - Float

    func showFloat() {
        showFloatOverlay = true
        cancelHideFloat()
        scheduleHideFloat()
    }

    func scheduleHideFloat() {
        cancelHideFloat()
        guard player.isReady else { return }
        floatTask = Task {
            try? await Task.sleep(nanoseconds: FLOAT_HIDE_MS)
            guard !Task.isCancelled else { return }
            await MainActor.run { hideFloat() }
        }
    }

    func cancelHideFloat() {
        floatTask?.cancel()
        floatTask = nil
    }

    func hideFloat() {
        showFloatOverlay = false
    }

    // MARK: - Actions

    func togglePanel() {
        guard !locked else { return }
        panelVisible.toggle()
        showFloat()
    }

    func toggleLock() {
        locked.toggle()
        if locked {
            panelVisible = false
            hideFloat()
        } else {
            showFloat()
        }
    }

    func pause() { player.pause() }
    func resume() { player.resume() }

    func adjustVolume(delta: Float) {
        player.volume = max(0, min(1, player.volume + delta))
        showFloat()
    }

    // MARK: - Delete line

    func confirmDeleteLine() {
        guard currentUrl != nil else { return }
        showDeleteAlert = true
    }

    func doDeleteLine() {
        guard let url = currentUrl, let ch = currentChannel else { return }
        storage.hideLine(url)
        let targetKey = ch.key
        let nextIdx = ch.sourceCount <= 1 ? -1 : currentSourceIndex
        let oldIdx = currentIndex

        let source = rawChannels.isEmpty ? channels : rawChannels
        channels = applyRules(source)

        guard !channels.isEmpty else {
            player.stop()
            currentIndex = 0
            currentSourceIndex = 0
            showIndicator("线路已删除")
            return
        }

        if let found = channels.firstIndex(where: { $0.key == targetKey }) {
            currentIndex = found
            let updated = channels[found]
            if updated.sourceCount <= 0 {
                nextChannel()
                return
            }
            currentSourceIndex = nextIdx >= 0 && nextIdx < updated.sourceCount ? nextIdx : 0
        } else {
            currentIndex = min(oldIdx, channels.count - 1)
            currentSourceIndex = 0
        }
        showIndicator("已删除当前线路")
        playCurrent()
    }
}

// MARK: - Ordered Dictionary

struct OrderedDictionary<Key: Hashable, Value> {
    private var _keys: [Key] = []
    private var dict: [Key: Value] = [:]

    var keys: [Key] { _keys }
    var values: [Value] { _keys.compactMap { dict[$0] } }

    subscript(key: Key) -> Value? {
        get { dict[key] }
        set {
            if newValue == nil {
                dict.removeValue(forKey: key)
                _keys.removeAll { $0 == key }
            } else if dict[key] == nil {
                _keys.append(key)
                dict[key] = newValue
            } else {
                dict[key] = newValue
            }
        }
    }
}
