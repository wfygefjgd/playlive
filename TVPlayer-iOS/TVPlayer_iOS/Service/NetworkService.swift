import Foundation

enum NetworkFetchError: LocalizedError {
    case invalidURL
    case badResponse
    case emptyBody
    case parseEmpty
    case allFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "地址无效"
        case .badResponse: return "服务器响应异常"
        case .emptyBody: return "内容为空"
        case .parseEmpty: return "解析不到频道"
        case .allFailed: return "所有源均加载失败"
        }
    }
}

final class NetworkService {
    static let shared = NetworkService()

    private let ua = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15"
    /// 列表拉取超时（秒）— 过长会拖慢首次失败切换
    private let timeout: TimeInterval = 8

    private lazy var session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = timeout
        cfg.timeoutIntervalForResource = timeout + 2
        cfg.waitsForConnectivity = false
        cfg.requestCachePolicy = .returnCacheDataElseLoad
        cfg.urlCache = URLCache(
            memoryCapacity: 4 * 1024 * 1024,
            diskCapacity: 32 * 1024 * 1024,
            diskPath: "tvplayer_url_cache"
        )
        cfg.httpAdditionalHeaders = ["User-Agent": ua]
        return URLSession(configuration: cfg)
    }()

    func fetch(url: String) async throws -> String {
        guard let u = URL(string: url), u.scheme != nil else {
            throw NetworkFetchError.invalidURL
        }
        var request = URLRequest(url: u, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: timeout)
        request.setValue(ua, forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw NetworkFetchError.badResponse
        }
        guard let text = String(data: data, encoding: .utf8), !text.isEmpty else {
            // 部分缓存/代理可能用其它编码
            if let text2 = String(data: data, encoding: .isoLatin1), !text2.isEmpty {
                return text2
            }
            throw NetworkFetchError.emptyBody
        }
        return text
    }

    /// 依次拉取候选；解析放后台线程，避免卡住主线程
    func fetchWithCandidates(urls: [String]) async -> (channels: [Channel], errorMessage: String?) {
        guard !urls.isEmpty else {
            return ([], NetworkFetchError.allFailed.errorDescription)
        }
        // 前两个源竞速：谁先解析出频道用谁（加快首次加载）
        if urls.count >= 2 {
            if let raced = await raceFetch(urls: Array(urls.prefix(2))) {
                return (raced, nil)
            }
        }
        var lastError: String?
        for url in urls {
            do {
                let body = try await fetch(url: url)
                let parsed = await parseOffMain(body)
                if parsed.isEmpty {
                    lastError = NetworkFetchError.parseEmpty.errorDescription
                    continue
                }
                return (parsed, nil)
            } catch let e as NetworkFetchError {
                lastError = e.errorDescription
            } catch {
                lastError = error.localizedDescription
            }
        }
        return ([], lastError ?? NetworkFetchError.allFailed.errorDescription)
    }

    private func raceFetch(urls: [String]) async -> [Channel]? {
        await withTaskGroup(of: [Channel]?.self) { group in
            for url in urls {
                group.addTask {
                    do {
                        let body = try await self.fetch(url: url)
                        let parsed = await self.parseOffMain(body)
                        return parsed.isEmpty ? nil : parsed
                    } catch {
                        return nil
                    }
                }
            }
            for await result in group {
                if let channels = result, !channels.isEmpty {
                    group.cancelAll()
                    return channels
                }
            }
            return nil
        }
    }

    private func parseOffMain(_ body: String) async -> [Channel] {
        await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                cont.resume(returning: M3UParserService.parse(body))
            }
        }
    }
}
