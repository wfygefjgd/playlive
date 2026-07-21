import SwiftUI
import AVKit

/// 完整显示画面：按容器宽高取 min 缩放，永不裁切
final class PlayerContainerView: UIView {
    let playerLayer = AVPlayerLayer()
    private var sizeObserver: NSKeyValueObservation?
    private var statusObserver: NSKeyValueObservation?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        clipsToBounds = true
        isUserInteractionEnabled = false
        playerLayer.videoGravity = .resizeAspect
        playerLayer.backgroundColor = UIColor.black.cgColor
        layer.addSublayer(playerLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(player: AVPlayer) {
        playerLayer.player = player
        sizeObserver?.invalidate()
        statusObserver?.invalidate()
        sizeObserver = player.currentItem?.observe(\.presentationSize, options: [.new, .initial]) { [weak self] _, _ in
            DispatchQueue.main.async { self?.setNeedsLayout() }
        }
        statusObserver = player.currentItem?.observe(\.status, options: [.new, .initial]) { [weak self] _, _ in
            DispatchQueue.main.async { self?.setNeedsLayout() }
        }
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let bw = bounds.width
        let bh = bounds.height
        guard bw > 1, bh > 1 else {
            playerLayer.frame = bounds
            return
        }

        let videoSize = playerLayer.player?.currentItem?.presentationSize ?? .zero
        if videoSize.width > 1, videoSize.height > 1 {
            // 完整装入：scale = min(bw/vw, bh/vh)，居中，不裁切
            let scale = min(bw / videoSize.width, bh / videoSize.height)
            let layerW = videoSize.width * scale
            let layerH = videoSize.height * scale
            playerLayer.frame = CGRect(
                x: (bw - layerW) / 2,
                y: (bh - layerH) / 2,
                width: layerW,
                height: layerH
            )
        } else {
            // 尺寸未知时先铺满层，由 videoGravity 自适应
            playerLayer.frame = bounds
        }
        playerLayer.videoGravity = .resizeAspect
    }
}

struct VideoPlayerView: UIViewRepresentable {
    @EnvironmentObject private var vm: PlayerViewModel

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.bind(player: vm.player.player)
        return view
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        uiView.bind(player: vm.player.player)
        uiView.setNeedsLayout()
    }
}
