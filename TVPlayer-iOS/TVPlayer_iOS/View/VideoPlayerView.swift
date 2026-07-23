import SwiftUI
import AVKit
import UIKit

/// 播放层强制盖住整个 UIWindow（含顶部刘海区、底部 Home 条区域）。
/// videoGravity = resize：在「真全屏矩形」上拉伸铺满。
final class PlayerContainerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    var player: AVPlayer? {
        get { playerLayer.player }
        set {
            playerLayer.player = newValue
            applyVideoStyle()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        isOpaque = true
        // 允许 layer 画到 safe area / 视图边界之外
        clipsToBounds = false
        isUserInteractionEnabled = false
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        applyVideoStyle()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
    }

    private func applyVideoStyle() {
        playerLayer.videoGravity = .resize
        playerLayer.backgroundColor = UIColor.black.cgColor
        playerLayer.masksToBounds = true
    }

    /// 把 layer 对齐到整个 window（吃掉 top/bottom safe area）
    private func layoutPlayerLayerToWindow() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if let window = window {
            // window 坐标系全屏 → 本 view 坐标系
            let full = window.convert(window.bounds, to: self)
            playerLayer.frame = full
        } else {
            playerLayer.frame = bounds
        }
        playerLayer.videoGravity = .resize
        CATransaction.commit()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutPlayerLayerToWindow()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        setNeedsLayout()
        layoutIfNeeded()
    }
}

struct VideoPlayerView: UIViewRepresentable {
    @EnvironmentObject private var vm: PlayerViewModel

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        view.player = vm.player.player
        return view
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        if uiView.player !== vm.player.player {
            uiView.player = vm.player.player
        }
        uiView.setNeedsLayout()
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: PlayerContainerView,
        context: Context
    ) -> CGSize? {
        // 始终按物理屏（横屏：宽=长边，高=短边）
        let b = UIScreen.main.bounds
        let sw = max(b.width, b.height)
        let sh = min(b.width, b.height)
        let w = max(proposal.width ?? sw, sw)
        let h = max(proposal.height ?? sh, sh)
        return CGSize(width: w, height: h)
    }
}
