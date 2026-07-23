import SwiftUI
import AVKit
import UIKit

/// 方案 C 加强：layer 与视图同大 + resize 拉伸，强制铺满容器（可变形，无黑边）
final class PlayerContainerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    var player: AVPlayer? {
        get { playerLayer.player }
        set {
            playerLayer.player = newValue
            applyStretch()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        isOpaque = true
        clipsToBounds = true
        isUserInteractionEnabled = false
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        applyStretch()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        // 不报告小固有尺寸，避免被压成中间一块
        CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
    }

    private func applyStretch() {
        playerLayer.videoGravity = .resize
        playerLayer.backgroundColor = UIColor.black.cgColor
        playerLayer.masksToBounds = true
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        // layerClass 就是 AVPlayerLayer，frame 跟随 bounds 即可
        playerLayer.frame = bounds
        playerLayer.videoGravity = .resize
        CATransaction.commit()
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
        uiView.playerLayer.videoGravity = .resize
        uiView.setNeedsLayout()
    }

    /// 按父布局（或整屏）尺寸撑满
    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: PlayerContainerView,
        context: Context
    ) -> CGSize? {
        let screen = UIScreen.main.bounds.size
        // 横屏时取较大边为宽
        let sw = max(screen.width, screen.height)
        let sh = min(screen.width, screen.height)
        let w = proposal.width ?? sw
        let h = proposal.height ?? sh
        // 若提议尺寸明显小于屏幕，仍用屏幕，避免被安全区裁成“四周黑框”
        return CGSize(
            width: max(w, sw * 0.98, 1),
            height: max(h, sh * 0.98, 1)
        )
    }
}
