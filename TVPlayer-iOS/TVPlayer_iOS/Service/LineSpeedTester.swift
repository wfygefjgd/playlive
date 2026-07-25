import Foundation

/// 线路质量数据
struct LineQuality: Codable {
    let url: String
    var responseTime: Int  // 毫秒
    var isAvailable: Bool
    var lastChecked: Date

    var score: Int {
        if !isAvailable { return Int.max }
        return responseTime
    }
}

/// 线路速度检测器
@MainActor
final class LineSpeedTester {
    static let shared = LineSpeedTester()

    private let session: URLSession
    private let timeout: TimeInterval = 5.0
    private var cache: [String: LineQuality] = [:]

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeout
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)"
        ]
        self.session = URLSession(configuration: config)
    }

    /// 测试单条线路速度
    func testLine(_ url: String) async -> LineQuality {
        // 检查缓存（5分钟内有效）
        if let cached = cache[url],
           Date().timeIntervalSince(cached.lastChecked) < 300 {
            return cached
        }

        guard let u = URL(string: url) else {
            return LineQuality(
                url: url,
                responseTime: Int.max,
                isAvailable: false,
                lastChecked: Date()
            )
        }

        var request = URLRequest(url: u)
        request.httpMethod = "HEAD"  // 只请求头部，不下载内容
        request.timeoutInterval = timeout

        let start = Date()
        do {
            let (_, response) = try await session.data(for: request)
            let elapsed = Int(Date().timeIntervalSince(start) * 1000)

            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else {
                return LineQuality(
                    url: url,
                    responseTime: Int.max,
                    isAvailable: false,
                    lastChecked: Date()
                )
            }

            let quality = LineQuality(
                url: url,
                responseTime: elapsed,
                isAvailable: true,
                lastChecked: Date()
            )
            cache[url] = quality
            return quality

        } catch {
            return LineQuality(
                url: url,
                responseTime: Int.max,
                isAvailable: false,
                lastChecked: Date()
            )
        }
    }

    /// 批量测试多条线路（并发）
    func testLines(_ urls: [String], maxConcurrent: Int = 8) async -> [LineQuality] {
        var results: [LineQuality] = []

        // 分批并发测试
        for batch in urls.chunked(into: maxConcurrent) {
            let batchResults = await withTaskGroup(of: LineQuality.self) { group in
                for url in batch {
                    group.addTask {
                        await self.testLine(url)
                    }
                }

                var collected: [LineQuality] = []
                for await result in group {
                    collected.append(result)
                }
                return collected
            }
            results.append(contentsOf: batchResults)
        }

        return results
    }

    /// 清除缓存
    func clearCache() {
        cache.removeAll()
    }
}

// MARK: - 辅助扩展

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
