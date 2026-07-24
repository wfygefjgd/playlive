import SwiftUI
import AVFoundation
import UIKit

@main
struct TVPlayerApp: App {
    @StateObject private var vm = PlayerViewModel()
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(vm)
                .preferredColorScheme(.dark)
                .statusBarHidden(true)
                // Home Indicator: hide when possible; when shown it floats over video
                .persistentSystemOverlays(.hidden)
                .defersSystemGestures(on: .all)
                .ignoresSafeArea(.all, edges: .all)
        }
    }
}

/// Ensures hosting controller prefers auto-hidden Home Indicator (video full-bleed under it).
final class AppDelegate: NSObject, UIApplicationDelegate {
    func applicationDidBecomeActive(_ application: UIApplication) {
        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            for window in scene.windows {
                window.backgroundColor = .black
                if let root = window.rootViewController {
                    root.setNeedsUpdateOfHomeIndicatorAutoHidden()
                    root.setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
                    // Prefer child that wants auto-hide if present
                    promoteHomeIndicator(from: root)
                }
            }
        }
        NotificationCenter.default.post(name: .tvPlayerNeedsRelayout, object: nil)
    }

    private func promoteHomeIndicator(from vc: UIViewController) {
        vc.setNeedsUpdateOfHomeIndicatorAutoHidden()
        for child in vc.children {
            promoteHomeIndicator(from: child)
        }
        if let presented = vc.presentedViewController {
            promoteHomeIndicator(from: presented)
        }
    }
}
