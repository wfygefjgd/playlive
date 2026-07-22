import SwiftUI
import AVKit

/// 全屏容器 + resizeAspect：
/// 横屏 16:9 内容通常「高度顶满、左右黑边、不裁切」；
/// 绝不使用 resizeAspectFill，避免左右裁切台标。
final class PlayerContainerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    var player: AVPlayer? {
        get { playerLayer.player }
        set {
            playerLayer.player = newValue
            playerLayer.videoGravity = .resizeAspect
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        clipsToBounds = true
        isUserInteractionEnabled = false
        contentMode = .scaleToFill
        playerLayer.videoGravity = .resizeAspect
        playerLayer.backgroundColor = UIColor.black.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // layer 必须与屏幕同大；黑边由 AVPlayer 在 layer 内 letterbox，不是缩小整个播放器
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
}
