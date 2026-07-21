import AVKit
import Combine

/// 方案 A：起播超时 + 播放中连续卡顿 + 开播保护
final class PlayerEngine: ObservableObject {
    /// 起播超时（秒）
    static let startupTimeoutNs: UInt64 = 10_000_000_000
    /// 播放中连续卡顿阈值
    static let stallTimeoutNs: UInt64 = 6_000_000_000
    /// ready 后保护期，避免刚起播误切
    static let readyProtectNs: UInt64 = 2_000_000_000

    let player = AVPlayer()
    private var cancellables = Set<AnyCancellable>()
    private var statusObserver: NSKeyValueObservation?
    private var playToken = 0
    private var startupTask: Task<Void, Never>?
    private var stallTask: Task<Void, Never>?
    private var protectTask: Task<Void, Never>?
    private var stallWatchEnabled = false
    private var continuousStall = false

    @Published var isReady = false
    @Published var isPlaying = false

    var onError: (() -> Void)?
    var onReady: (() -> Void)?
    /// 起播超时（未 ready）
    var onStartupTimeout: (() -> Void)?
    /// 正常播放后连续卡顿
    var onPlaybackStall: (() -> Void)?

    init() {
        player.actionAtItemEnd = .none
        player.automaticallyWaitsToMinimizeStalling = true
        observeTimeControl()
    }

    func play(url: URL) {
        pause()
        playToken += 1
        let token = playToken
        cancelAllWatchers()
        statusObserver?.invalidate()
        stallWatchEnabled = false
        continuousStall = false

        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        isReady = false
        isPlaying = true

        statusObserver = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard let self else { return }
            if item.status == .readyToPlay {
                DispatchQueue.main.async {
                    guard self.playToken == token else { return }
                    self.handleReady(token: token)
                }
            } else if item.status == .failed {
                DispatchQueue.main.async {
                    guard self.playToken == token else { return }
                    self.cancelAllWatchers()
                    self.onError?()
                }
            }
        }

        scheduleStartupTimeout(token: token)
        player.play()
    }

    func pause() {
        player.pause()
        isPlaying = false
    }

    func resume() {
        guard player.currentItem != nil else { return }
        player.play()
        isPlaying = true
    }

    func stop() {
        playToken += 1
        statusObserver?.invalidate()
        statusObserver = nil
        cancelAllWatchers()
        player.replaceCurrentItem(with: nil)
        isPlaying = false
        isReady = false
        stallWatchEnabled = false
        continuousStall = false
    }

    var volume: Float {
        get { player.volume }
        set { player.volume = max(0, min(1, newValue)) }
    }

    // MARK: - Ready / startup

    private func handleReady(token: Int) {
        guard playToken == token else { return }
        cancelStartup()
        isReady = true
        player.play()
        isPlaying = true
        onReady?()
        // 开播保护后再允许卡顿检测
        stallWatchEnabled = false
        protectTask?.cancel()
        protectTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.readyProtectNs)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self, self.playToken == token else { return }
                self.stallWatchEnabled = true
            }
        }
    }

    private func scheduleStartupTimeout(token: Int) {
        cancelStartup()
        startupTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.startupTimeoutNs)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self, self.playToken == token, !self.isReady else { return }
                self.cancelAllWatchers()
                self.onStartupTimeout?()
            }
        }
    }

    // MARK: - Stall (only after protect)

    private func observeTimeControl() {
        player.publisher(for: \.timeControlStatus)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self else { return }
                self.isPlaying = status == .playing
                self.handleTimeControl(status)
            }
            .store(in: &cancellables)
    }

    private func handleTimeControl(_ status: AVPlayer.TimeControlStatus) {
        guard stallWatchEnabled, isReady else {
            if status == .playing || status == .paused {
                stopStallTimer()
            }
            return
        }
        switch status {
        case .waitingToPlayAtSpecifiedRate:
            beginStallTimerIfNeeded()
        case .playing:
            stopStallTimer()
        case .paused:
            stopStallTimer()
        @unknown default:
            break
        }

        // 缓冲空也视为卡顿信号
        if let item = player.currentItem, item.isPlaybackBufferEmpty, status != .playing {
            beginStallTimerIfNeeded()
        }
    }

    private func beginStallTimerIfNeeded() {
        guard continuousStall == false else { return }
        continuousStall = true
        let token = playToken
        stallTask?.cancel()
        stallTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.stallTimeoutNs)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self, self.playToken == token, self.stallWatchEnabled else { return }
                // 仍在 waiting 或 buffer 空
                let waiting = self.player.timeControlStatus == .waitingToPlayAtSpecifiedRate
                let empty = self.player.currentItem?.isPlaybackBufferEmpty == true
                guard waiting || empty else {
                    self.continuousStall = false
                    return
                }
                self.continuousStall = false
                self.stallTask = nil
                self.onPlaybackStall?()
            }
        }
    }

    private func stopStallTimer() {
        continuousStall = false
        stallTask?.cancel()
        stallTask = nil
    }

    private func cancelStartup() {
        startupTask?.cancel()
        startupTask = nil
    }

    private func cancelAllWatchers() {
        cancelStartup()
        stopStallTimer()
        protectTask?.cancel()
        protectTask = nil
    }
}
