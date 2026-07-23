import SwiftUI
import AVFoundation

@main
struct TVPlayerApp: App {
    @StateObject private var vm = PlayerViewModel()

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
                // 尽量隐藏底部 Home 指示条占用的视觉空白
                .persistentSystemOverlays(.hidden)
                .ignoresSafeArea(.all, edges: .all)
        }
    }
}
