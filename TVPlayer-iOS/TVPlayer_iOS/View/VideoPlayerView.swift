import SwiftUI
import AVKit
import UIKit
import Combine

// MARK: - 挂到 UIWindow 底层的全屏播放宿主（绕过 SwiftUI safe area / clips）

final class WindowPlayerHost {
    static let shared = WindowPlayerHost()

    private let container = UIView(frame: .zero)
    private let playerLayer = AVPlayerLayer()
    private var boundPlayer: AVPlayer?
    private var cancellables = Set<AnyCancellable>()
    private var installedWindow: UIWindow?
    private var delayItems: [DispatchWorkItem] = []

    private init() {
        container.backgroundColor = .black
        container.isUserInteractionEnabled = false
        container.clipsToBounds = true
        container.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.backgroundColor = UIColor.black.cgColor
        container.layer.addSublayer(playerLayer)

        let notes: [Notification.Name] = [
            UIApplication.didBecomeActiveNotification,
            UIApplication.willEnterForegroundNotification,
            UIDevice.orientationDidChangeNotification,
            .tvPlayerNeedsRelayout
        ]
        for n in notes {
            NotificationCenter.default.publisher(for: n)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in self?.relayout(reason: n.rawValue) }
                .store(in: &cancellables)
        }
    }

    func attach(player: AVPlayer?) {
        boundPlayer = player
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspectFill
        ensureOnKeyWindow()
        relayout(reason: "attach")
        schedulePasses()
    }

    func detach() {
        delayItems.forEach { $0.cancel() }
        delayItems.removeAll()
        playerLayer.player = nil
        boundPlayer = nil
        container.removeFromSuperview()
        installedWindow = nil
    }

    func ensureOnKeyWindow() {
        guard let window = keyWindow() else { return }
        if container.superview !== window {
            // 插到最底层，SwiftUI 内容盖在上面
            window.insertSubview(container, at: 0)
            installedWindow = window
        }
        // 父级若 clip，会裁掉全屏——尽量关掉
        var v: UIView? = container
        while let cur = v {
            cur.clipsToBounds = false
            v = cur.superview
        }
        container.clipsToBounds = true
    }

    func relayout(reason: String) {
        ensureOnKeyWindow()
        guard let window = container.window ?? keyWindow() else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        container.frame = window.bounds
        playerLayer.frame = container.bounds
        playerLayer.videoGravity = .resizeAspectFill
        if playerLayer.player == nil, let p = boundPlayer {
            playerLayer.player = p
        }
        CATransaction.commit()
        // 保证在 SwiftUI 根视图之下
        if let window = container.window {
            window.sendSubviewToBack(container)
        }
    }

    private func schedulePasses() {
        delayItems.forEach { $0.cancel() }
        delayItems.removeAll()
        // 首次布局 / Home 条 inset 晚到：多拍几次
        for t in [0.0, 0.05, 0.12, 0.25, 0.5, 1.0, 1.5] {
            let item = DispatchWorkItem { [weak self] in
                self?.relayout(reason: "delay-\(t)")
            }
            delayItems.append(item)
            DispatchQueue.main.asyncAfter(deadline: .now() + t, execute: item)
        }
    }

    private func keyWindow() -> UIWindow? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for scene in scenes {
            if let w = scene.windows.first(where: \.isKeyWindow) { return w }
        }
        return scenes.first?.windows.first
    }
}

// MARK: - SwiftUI：占位 + 驱动 window 宿主

/// 透明占位；真正画面在 WindowPlayerHost（window 最底层全屏）
final class PlayerPlaceholderView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            WindowPlayerHost.shared.ensureOnKeyWindow()
            WindowPlayerHost.shared.relayout(reason: "placeholder-window")
            WindowPlayerHost.shared.attach(player: WindowPlayerHost.sharedPlayerRef)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        WindowPlayerHost.shared.relayout(reason: "placeholder-layout")
    }
}

extension WindowPlayerHost {
    /// 给 placeholder 取当前 player 用（由 Representable 写入）
    fileprivate static weak var sharedPlayerRef: AVPlayer?
}

struct VideoPlayerView: UIViewRepresentable {
    @EnvironmentObject private var vm: PlayerViewModel

    func makeUIView(context: Context) -> PlayerPlaceholderView {
        let v = PlayerPlaceholderView()
        WindowPlayerHost.sharedPlayerRef = vm.player.player
        WindowPlayerHost.shared.attach(player: vm.player.player)
        return v
    }

    func updateUIView(_ uiView: PlayerPlaceholderView, context: Context) {
        WindowPlayerHost.sharedPlayerRef = vm.player.player
        WindowPlayerHost.shared.attach(player: vm.player.player)
        // 驱动：就绪 epoch 变化时再铺
        _ = vm.playerLayoutEpoch
        if vm.player.isReady {
            WindowPlayerHost.shared.relayout(reason: "ready-epoch")
        }
    }

    static func dismantleUIView(_ uiView: PlayerPlaceholderView, coordinator: ()) {
        // 不在 dismantle 里 detach，避免 SwiftUI 刷新时黑屏；App 生命周期内常驻
    }
}

extension Notification.Name {
    static let tvPlayerNeedsRelayout = Notification.Name("tvPlayerNeedsRelayout")
}
