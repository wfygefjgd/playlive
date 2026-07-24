import SwiftUI
import AVFoundation
import UIKit

@main
struct TVPlayerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var vm = PlayerViewModel()

    init() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    var body: some Scene {
        WindowGroup {
            // Use custom hosting so Home Indicator can auto-hide and not reserve layout space
            RootView(vm: vm)
                .ignoresSafeArea(.all, edges: .all)
        }
    }
}

/// Wraps ContentView in RootHostingController (home indicator policy + clear background)
struct RootView: UIViewControllerRepresentable {
    @ObservedObject var vm: PlayerViewModel

    func makeUIViewController(context: Context) -> RootHostingController<AnyView> {
        let root = ContentView()
            .environmentObject(vm)
            .preferredColorScheme(.dark)
            .statusBarHidden(true)
            .persistentSystemOverlays(.hidden)
            .defersSystemGestures(on: .all)
            .background(Color.clear)
        let host = RootHostingController(rootView: AnyView(root))
        host.view.backgroundColor = .clear
        return host
    }

    func updateUIViewController(_ uiViewController: RootHostingController<AnyView>, context: Context) {
        let root = ContentView()
            .environmentObject(vm)
            .preferredColorScheme(.dark)
            .statusBarHidden(true)
            .persistentSystemOverlays(.hidden)
            .defersSystemGestures(on: .all)
            .background(Color.clear)
        uiViewController.rootView = AnyView(root)
        uiViewController.setNeedsUpdateOfHomeIndicatorAutoHidden()
        uiViewController.setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            for window in scene.windows {
                window.backgroundColor = .black
                if let root = window.rootViewController {
                    root.view.backgroundColor = .clear
                    root.view.isOpaque = false
                    root.setNeedsUpdateOfHomeIndicatorAutoHidden()
                    root.setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
                }
            }
        }
        WindowVideoSurface.shared.install()
        NotificationCenter.default.post(name: .tvPlayerNeedsRelayout, object: nil)
    }
}
