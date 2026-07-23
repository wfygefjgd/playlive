import SwiftUI
import AVKit
import UIKit

/// 全屏容器 + contain（resizeAspect）
/// 对应 Flutter BoxFit.contain / RN resizeMode="contain"
final class PlayerContainerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    var player: AVPlayer? {
        get { playerLayer.player }
        set {
            playerLayer.player = newValue
            playerLayer.videoGravity = .resizeAspect
            playerLayer.backgroundColor = UIColor.black.cgColor
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        isOpaque = true
        clipsToBounds = true
        isUserInteractionEnabled = false
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        playerLayer.videoGravity = .resizeAspect
        playerLayer.backgroundColor = UIColor.black.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 避免 UIView 报告过小的固有尺寸，导致四周“空一圈”
    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        playerLayer.frame = bounds
        playerLayer.videoGravity = .resizeAspect
        CATransaction.commit()
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
        uiView.playerLayer.videoGravity = .resizeAspect
        uiView.setNeedsLayout()
    }

    /// iOS 16+：按父布局提议的尺寸铺满（去掉固定宽高）
    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: PlayerContainerView,
        context: Context
    ) -> CGSize? {
        let screen = UIScreen.main.bounds.size
        let w = proposal.width ?? screen.width
        let h = proposal.height ?? screen.height
        return CGSize(width: max(w, 1), height: max(h, 1))
    }
}
