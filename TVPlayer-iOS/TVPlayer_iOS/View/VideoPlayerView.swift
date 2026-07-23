import SwiftUI
import AVKit
import UIKit
import Combine

/// 全屏播放：layer 对齐 window；在 window 就绪 / 回前台 / 播放就绪时强制 relayout
/// （修复：首次进入底边空一条，退后台再回才铺满）
final class FullScreenPlayerViewController: UIViewController {
    private let playerLayer = AVPlayerLayer()
    private var cancellables = Set<AnyCancellable>()
    private var layoutWorkItems: [DispatchWorkItem] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        view.clipsToBounds = false
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.backgroundColor = UIColor.black.cgColor
        view.layer.addSublayer(playerLayer)
        edgesForExtendedLayout = .all
        extendedLayoutIncludesOpaqueBars = true
        if #available(iOS 11.0, *) {
            additionalSafeAreaInsets = .zero
        }

        // 回前台时系统会重算 safe area —— 再铺一次
        let names: [Notification.Name] = [
            UIApplication.didBecomeActiveNotification,
            UIApplication.willEnterForegroundNotification,
            UIDevice.orientationDidChangeNotification,
            .tvPlayerNeedsRelayout
        ]
        for name in names {
            NotificationCenter.default.publisher(for: name)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.forceRelayout(reason: name.rawValue)
                    self?.scheduleRelayoutPasses()
                }
                .store(in: &cancellables)
        }
    }

    deinit {
        layoutWorkItems.forEach { $0.cancel() }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        forceRelayout(reason: "didAppear")
        // 首次启动 window/safeArea 会晚到：分几次补铺
        scheduleRelayoutPasses()
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        if #available(iOS 11.0, *) {
            let s = view.safeAreaInsets
            additionalSafeAreaInsets = UIEdgeInsets(
                top: -s.top, left: -s.left, bottom: -s.bottom, right: -s.right
            )
        }
        layoutPlayer()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutPlayer()
    }

    func bind(player: AVPlayer?) {
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspectFill
        forceRelayout(reason: "bind")
    }

    /// 播放真正 ready 时由外部调用，模拟「回前台 relayout」
    func onPlaybackReady() {
        forceRelayout(reason: "playbackReady")
        scheduleRelayoutPasses()
    }

    func forceRelayout(reason: String) {
        view.setNeedsLayout()
        view.layoutIfNeeded()
        layoutPlayer()
        // 再进一轮 runloop，等 window bounds 稳定
        DispatchQueue.main.async { [weak self] in
            self?.layoutPlayer()
        }
    }

    private func scheduleRelayoutPasses() {
        layoutWorkItems.forEach { $0.cancel() }
        layoutWorkItems.removeAll()
        // 0.05 / 0.15 / 0.4 / 1.0 秒各补一次（覆盖首次布局晚到）
        for delay in [0.05, 0.15, 0.4, 1.0] {
            let work = DispatchWorkItem { [weak self] in
                self?.layoutPlayer()
            }
            layoutWorkItems.append(work)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        }
    }

    private func layoutPlayer() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if let window = view.window {
            // 物理全屏：window.bounds → 本 view 坐标
            playerLayer.frame = view.convert(window.bounds, from: nil)
        } else if let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
                  let win = scene.windows.first(where: \.isKeyWindow) ?? scene.windows.first {
            playerLayer.frame = view.convert(win.bounds, from: nil)
        } else if view.bounds.width > 1, view.bounds.height > 1 {
            playerLayer.frame = view.bounds
        } else {
            let b = UIScreen.main.bounds
            playerLayer.frame = CGRect(
                x: 0, y: 0,
                width: max(b.width, b.height),
                height: min(b.width, b.height)
            )
        }
        // 兜底：绝不能小于 view
        if playerLayer.superlayer == nil {
            view.layer.addSublayer(playerLayer)
        }
        if playerLayer.frame.width < view.bounds.width - 0.5
            || playerLayer.frame.height < view.bounds.height - 0.5 {
            playerLayer.frame = view.bounds
        }
        playerLayer.videoGravity = .resizeAspectFill
        CATransaction.commit()
    }
}

struct VideoPlayerView: UIViewControllerRepresentable {
    @EnvironmentObject private var vm: PlayerViewModel

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> FullScreenPlayerViewController {
        let vc = FullScreenPlayerViewController()
        context.coordinator.vc = vc
        vc.bind(player: vm.player.player)
        return vc
    }

    func updateUIViewController(_ uiViewController: FullScreenPlayerViewController, context: Context) {
        context.coordinator.vc = uiViewController
        uiViewController.bind(player: vm.player.player)
        // epoch 变化 / isReady → 强制 relayout（复现退后台再回才满的那次）
        _ = vm.playerLayoutEpoch
        if vm.player.isReady {
            uiViewController.onPlaybackReady()
        } else {
            uiViewController.forceRelayout(reason: "update")
        }
    }

    final class Coordinator {
        weak var vc: FullScreenPlayerViewController?
    }
}

extension Notification.Name {
    static let tvPlayerNeedsRelayout = Notification.Name("tvPlayerNeedsRelayout")
}
