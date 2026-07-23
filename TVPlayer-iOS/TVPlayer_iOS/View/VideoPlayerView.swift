import SwiftUI
import AVKit
import UIKit
import Combine

/// 基于 1.3.4：画面在 SwiftUI 内（有画有声）。
/// 强化：首次布局对齐「回前台」——吃掉 Home 条安全区，并在 inset 稳定后反复铺满 window。
final class FullScreenPlayerViewController: UIViewController {
    private let playerLayer = AVPlayerLayer()
    private var cancellables = Set<AnyCancellable>()
    private var delayItems: [DispatchWorkItem] = []

    /// 让系统按「可隐藏 Home 指示条」处理（接近你回前台后的状态）
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge { [.bottom, .top] }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        view.clipsToBounds = false
        view.isOpaque = true
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.backgroundColor = UIColor.black.cgColor
        view.layer.addSublayer(playerLayer)

        edgesForExtendedLayout = .all
        extendedLayoutIncludesOpaqueBars = true
        if #available(iOS 11.0, *) {
            additionalSafeAreaInsets = .zero
        }

        let notes: [Notification.Name] = [
            UIApplication.didBecomeActiveNotification,
            UIApplication.willEnterForegroundNotification,
            UIDevice.orientationDidChangeNotification,
            .tvPlayerNeedsRelayout
        ]
        for name in notes {
            NotificationCenter.default.publisher(for: name)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.applyHomeIndicatorPolicy()
                    self?.forceRelayout()
                    self?.scheduleRelayoutPasses()
                }
                .store(in: &cancellables)
        }
    }

    deinit { delayItems.forEach { $0.cancel() } }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        applyHomeIndicatorPolicy()
        forceRelayout()
        scheduleRelayoutPasses()
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        // 抵消安全区，让布局矩形 = 物理全屏（含 Home 条区域）
        neutralizeSafeArea()
        layoutPlayer()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        neutralizeSafeArea()
        layoutPlayer()
    }

    private func applyHomeIndicatorPolicy() {
        setNeedsUpdateOfHomeIndicatorAutoHidden()
        setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
    }

    private func neutralizeSafeArea() {
        if #available(iOS 11.0, *) {
            let s = view.safeAreaInsets
            // 用负 inset 把 safe area「抵消掉」，与回前台后满屏一致
            additionalSafeAreaInsets = UIEdgeInsets(
                top: -s.top,
                left: -s.left,
                bottom: -s.bottom,
                right: -s.right
            )
        }
    }

    func bind(player: AVPlayer?) {
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspectFill
        forceRelayout()
    }

    func onPlaybackReady() {
        applyHomeIndicatorPolicy()
        forceRelayout()
        scheduleRelayoutPasses()
    }

    func forceRelayout() {
        neutralizeSafeArea()
        view.setNeedsLayout()
        view.layoutIfNeeded()
        layoutPlayer()
        DispatchQueue.main.async { [weak self] in
            self?.neutralizeSafeArea()
            self?.layoutPlayer()
        }
    }

    /// 模拟「回前台」：Home 条 / window 尺寸稳定后的多次补铺
    private func scheduleRelayoutPasses() {
        delayItems.forEach { $0.cancel() }
        delayItems.removeAll()
        // 比 1.3.4 稍密：覆盖首次 Home 条 inset 晚到
        for t in [0.0, 0.05, 0.1, 0.2, 0.4, 0.8, 1.2, 2.0] {
            let item = DispatchWorkItem { [weak self] in
                self?.applyHomeIndicatorPolicy()
                self?.neutralizeSafeArea()
                self?.layoutPlayer()
            }
            delayItems.append(item)
            DispatchQueue.main.asyncAfter(deadline: .now() + t, execute: item)
        }
    }

    private func layoutPlayer() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if playerLayer.superlayer == nil {
            view.layer.addSublayer(playerLayer)
        }

        // 始终以 window 物理全屏为目标（含 Home 条区域）
        if let window = view.window {
            var full = window.bounds
            // 兜底：某些时刻 bounds 仍偏小，用 screen
            let screen = window.screen.bounds
            if full.width * full.height < screen.width * screen.height * 0.95 {
                full = screen
            }
            playerLayer.frame = view.convert(full, from: nil)
        } else if view.bounds.width > 2, view.bounds.height > 2 {
            playerLayer.frame = view.bounds
        } else {
            let b = UIScreen.main.bounds
            playerLayer.frame = CGRect(
                x: 0, y: 0,
                width: max(b.width, b.height),
                height: min(b.width, b.height)
            )
        }

        // 不能比 view 更小
        if view.bounds.width > 2, view.bounds.height > 2 {
            if playerLayer.frame.width < view.bounds.width - 0.5
                || playerLayer.frame.height < view.bounds.height - 0.5 {
                playerLayer.frame = view.bounds
            }
        }

        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.isHidden = false
        playerLayer.opacity = 1
        CATransaction.commit()
    }
}

struct VideoPlayerView: UIViewControllerRepresentable {
    @EnvironmentObject private var vm: PlayerViewModel

    func makeUIViewController(context: Context) -> FullScreenPlayerViewController {
        let vc = FullScreenPlayerViewController()
        vc.bind(player: vm.player.player)
        return vc
    }

    func updateUIViewController(_ vc: FullScreenPlayerViewController, context: Context) {
        vc.bind(player: vm.player.player)
        _ = vm.playerLayoutEpoch
        if vm.player.isReady {
            vc.onPlaybackReady()
        } else {
            vc.forceRelayout()
        }
    }
}

extension Notification.Name {
    static let tvPlayerNeedsRelayout = Notification.Name("tvPlayerNeedsRelayout")
}
