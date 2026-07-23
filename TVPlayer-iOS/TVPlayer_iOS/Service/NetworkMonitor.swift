import Foundation
import Network

/// 监听网络可用；首次点「允许网络」后 status 变 satisfied 会回调
final class NetworkMonitor {
    static let shared = NetworkMonitor()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "tvplayer.network.monitor")
    private(set) var isSatisfied = false

    var onSatisfied: (() -> Void)? {
        didSet {
            // 若设置回调时网络已可用，立即通知一次（首次授权后常见）
            if isSatisfied {
                DispatchQueue.main.async { [weak self] in
                    self?.onSatisfied?()
                }
            }
        }
    }

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let ok = path.status == .satisfied
            DispatchQueue.main.async {
                guard let self else { return }
                let was = self.isSatisfied
                self.isSatisfied = ok
                if ok && !was {
                    self.onSatisfied?()
                }
            }
        }
        monitor.start(queue: queue)
        // 初始路径
        let ok = monitor.currentPath.status == .satisfied
        isSatisfied = ok
    }
}
