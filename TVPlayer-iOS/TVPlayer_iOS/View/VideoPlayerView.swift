import SwiftUI
import AVKit

struct VideoPlayerView: UIViewRepresentable {
    @EnvironmentObject private var vm: PlayerViewModel

    func makeUIView(context: Context) -> UIView {
        PlayerView(player: vm.player.player)
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let view = uiView as? PlayerView else { return }
        view.player = vm.player.player
    }
}

private class PlayerView: UIView {
    var player: AVPlayer? {
        didSet { playerLayer.player = player }
    }

    private var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }

    override class var layerClass: AnyClass { AVPlayerLayer.self }

    init(player: AVPlayer?) {
        super.init(frame: .zero)
        backgroundColor = .black
        playerLayer.videoGravity = .resizeAspectFill
        self.player = player
    }

    required init?(coder: NSCoder) { nil }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }
}
