import AVFoundation
import MediaPlayer
import UIKit

/// 系统音量调节 — 通过 MPVolumeView 公开 API 实现
/// 避免直接操作 slider.value（私有 API 风险）
enum VolumeHelper {
    private static var volumeView: MPVolumeView?
    private static var volumeSlider: UISlider?

    /// 当前系统音量 (0.0 - 1.0)
    static var current: Float {
        AVAudioSession.sharedInstance().outputVolume
    }

    private static func ensureInstalled() {
        guard volumeView == nil else {
            // 已安装但 slider 可能尚未就绪（极少情况）
            if volumeSlider == nil {
                volumeSlider = volumeView?.subviews.compactMap { $0 as? UISlider }.first
            }
            return
        }

        let view = MPVolumeView(frame: CGRect(x: -1000, y: -1000, width: 1, height: 1))
        view.alpha = 0.001
        view.isUserInteractionEnabled = false
        view.showsRouteButton = false
        volumeView = view
        volumeSlider = view.subviews.compactMap { $0 as? UISlider }.first

        if let window = keyWindow() {
            window.insertSubview(view, at: 0)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak view] in
                guard let view, let window = keyWindow(), view.superview == nil else { return }
                window.insertSubview(view, at: 0)
                if volumeSlider == nil {
                    volumeSlider = view.subviews.compactMap { $0 as? UISlider }.first
                }
            }
        }
    }

    private static func keyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
    }

    /// 设置音量 (0.0 - 1.0) — 带系统音量 HUD 显示
    static func setVolume(_ value: Float) {
        ensureInstalled()
        let clamped = max(0, min(1, value))

        // 使用 animated: true 显示系统音量 HUD，体验更友好
        if let slider = volumeSlider {
            DispatchQueue.main.async {
                slider.setValue(clamped, animated: true)
            }
        } else {
            // slider 尚未就绪，延迟重试
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak volumeView] in
                if volumeSlider == nil {
                    volumeSlider = volumeView?.subviews.compactMap { $0 as? UISlider }.first
                }
                volumeSlider?.setValue(clamped, animated: true)
            }
        }
    }

    /// 调整音量（相对值）
    static func adjust(by delta: Float) {
        setVolume(current + delta)
    }

    /// 触觉反馈（用于音量调节时）
    static func hapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.impactOccurred(intensity: 0.5)
    }
}
