import AVFoundation
import MediaPlayer
import UIKit

/// 读写系统媒体音量（非仅 AVPlayer.volume）
enum VolumeHelper {
    static var current: Float {
        AVAudioSession.sharedInstance().outputVolume
    }

    static func setVolume(_ value: Float) {
        let v = max(0, min(1, value))
        let view = MPVolumeView(frame: .zero)
        // 离屏避免闪一下
        view.alpha = 0.0001
        view.isUserInteractionEnabled = false
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) else {
            // 回退：只改 session 无法直接写，尝试找 slider
            applyToSlider(in: view, value: v)
            return
        }
        window.addSubview(view)
        applyToSlider(in: view, value: v)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            view.removeFromSuperview()
        }
    }

    static func adjust(by delta: Float) {
        setVolume(current + delta)
    }

    private static func applyToSlider(in volumeView: MPVolumeView, value: Float) {
        let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            slider?.value = value
        }
    }
}
