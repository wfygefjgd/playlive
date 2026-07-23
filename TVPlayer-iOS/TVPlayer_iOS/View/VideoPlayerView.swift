import SwiftUI
import AVKit
import UIKit

/// 方案 C：强制拉伸铺满（resize）
/// 上下左右都顶满屏幕，允许画面变形，方便对照观感。
final class PlayerContainerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    var player: AVPlayer? {
        get { playerLayer.player }
        set {
            playerLayer.player = newValue
            playerLayer.videoGravity = .resize
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
        playerLayer.videoGravity = .resize
        playerLayer.backgroundColor = UIColor.black.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        playerLayer.frame = bounds
        playerLayer.videoGravity = .resize
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
        uiView.playerLayer.videoGravity = .resize
        uiView.setNeedsLayout()
    }

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
