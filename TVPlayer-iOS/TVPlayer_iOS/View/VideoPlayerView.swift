import SwiftUI
import AVKit
import UIKit
import Combine

// MARK: - Window full-bleed surface (video under Home Indicator)

/// Pins AVPlayerLayer to keyWindow edges (NOT safeAreaLayoutGuide).
/// Home Indicator then floats over video instead of reserving a black strip.
final class WindowVideoSurface {
    static let shared = WindowVideoSurface()

    private let host = TouchThroughView(frame: .zero)
    private let playerLayer = AVPlayerLayer()
    private var constraints: [NSLayoutConstraint] = []
    private var cancellables = Set<AnyCancellable>()
    private var delayItems: [DispatchWorkItem] = []
    private weak var boundPlayer: AVPlayer?

    private init() {
        host.backgroundColor = .black
        host.translatesAutoresizingMaskIntoConstraints = false
        host.isUserInteractionEnabled = false
        playerLayer.videoGravity = .resize
        playerLayer.backgroundColor = UIColor.black.cgColor
        host.layer.addSublayer(playerLayer)

        for name: Notification.Name in [
            UIApplication.didBecomeActiveNotification,
            UIApplication.willEnterForegroundNotification,
            UIDevice.orientationDidChangeNotification,
            .tvPlayerNeedsRelayout
        ] {
            NotificationCenter.default.publisher(for: name)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in self?.install() }
                .store(in: &cancellables)
        }
    }

    func setPlayer(_ player: AVPlayer?) {
        boundPlayer = player
        playerLayer.player = player
        playerLayer.videoGravity = .resize
        install()
        schedulePasses()
    }

    func install() {
        guard let window = Self.keyWindow() else { return }

        // Critical: hosting view must be clear so window video is visible
        window.backgroundColor = .black
        if let root = window.rootViewController?.view {
            root.backgroundColor = .clear
            root.isOpaque = false
            // Do not clip video that extends into home area
            root.clipsToBounds = false
        }

        if host.superview !== window {
            constraints.forEach { $0.isActive = false }
            constraints.removeAll()
            host.removeFromSuperview()
            // Insert behind all SwiftUI content
            window.insertSubview(host, at: 0)
            // Pin to WINDOW edges (full physical screen), not safe area
            let c = [
                host.topAnchor.constraint(equalTo: window.topAnchor),
                host.bottomAnchor.constraint(equalTo: window.bottomAnchor),
                host.leadingAnchor.constraint(equalTo: window.leadingAnchor),
                host.trailingAnchor.constraint(equalTo: window.trailingAnchor)
            ]
            NSLayoutConstraint.activate(c)
            constraints = c
        } else {
            window.sendSubviewToBack(host)
        }

        host.layoutIfNeeded()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        var frame = host.bounds
        if frame.width < 2 || frame.height < 2 {
            frame = window.bounds
            host.frame = window.bounds
        }
        playerLayer.frame = frame
        playerLayer.videoGravity = .resize
        playerLayer.isHidden = false
        playerLayer.opacity = 1
        if playerLayer.player == nil {
            playerLayer.player = boundPlayer
        }
        CATransaction.commit()

        // Keep asking system to auto-hide home indicator when allowed
        window.rootViewController?.setNeedsUpdateOfHomeIndicatorAutoHidden()
        window.rootViewController?.setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
    }

    private func schedulePasses() {
        delayItems.forEach { $0.cancel() }
        delayItems.removeAll()
        for t in [0.0, 0.05, 0.12, 0.25, 0.5, 1.0, 1.5, 2.5] {
            let item = DispatchWorkItem { [weak self] in self?.install() }
            delayItems.append(item)
            DispatchQueue.main.asyncAfter(deadline: .now() + t, execute: item)
        }
    }

    private static func keyWindow() -> UIWindow? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for scene in scenes where scene.activationState == .foregroundActive {
            if let w = scene.windows.first(where: \.isKeyWindow) { return w }
            if let w = scene.windows.first { return w }
        }
        return scenes.flatMap(\.windows).first
    }
}

/// Touches pass through to SwiftUI controls above
private final class TouchThroughView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? { nil }

    override func layoutSubviews() {
        super.layoutSubviews()
        if let layer = layer.sublayers?.compactMap({ $0 as? AVPlayerLayer }).first {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            layer.frame = bounds
            CATransaction.commit()
        }
    }
}

// MARK: - SwiftUI anchor (transparent; video lives on window)

final class PlayerAnchorView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        WindowVideoSurface.shared.install()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        WindowVideoSurface.shared.install()
    }
}

struct VideoPlayerView: UIViewRepresentable {
    @EnvironmentObject private var vm: PlayerViewModel

    func makeUIView(context: Context) -> PlayerAnchorView {
        let v = PlayerAnchorView()
        WindowVideoSurface.shared.setPlayer(vm.player.player)
        return v
    }

    func updateUIView(_ uiView: PlayerAnchorView, context: Context) {
        WindowVideoSurface.shared.setPlayer(vm.player.player)
        _ = vm.playerLayoutEpoch
        WindowVideoSurface.shared.install()
    }
}

// MARK: - Hosting controller that prefers auto-hidden Home Indicator

final class RootHostingController<Content: View>: UIHostingController<Content> {
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge { .all }
    override var prefersStatusBarHidden: Bool { true }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.isOpaque = false
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setNeedsUpdateOfHomeIndicatorAutoHidden()
        setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
        NotificationCenter.default.post(name: .tvPlayerNeedsRelayout, object: nil)
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        // Do not shrink for home indicator — content draws edge-to-edge
        NotificationCenter.default.post(name: .tvPlayerNeedsRelayout, object: nil)
    }
}

extension Notification.Name {
    static let tvPlayerNeedsRelayout = Notification.Name("tvPlayerNeedsRelayout")
}
