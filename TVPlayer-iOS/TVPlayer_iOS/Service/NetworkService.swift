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

    private let ua = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)"
    private let timeout: TimeInterval = 12

    func fetch(url: String) async throws -> String {
        guard let u = URL(string: url), u.scheme != nil else {
            throw NetworkFetchError.invalidURL
        }
        var request = URLRequest(url: u)
        request.setValue(ua, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = timeout
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw NetworkFetchError.badResponse
        }
        guard let text = String(data: data, encoding: .utf8), !text.isEmpty else {
            throw NetworkFetchError.emptyBody
        }
        return text
    }

    /// 按候选 URL 依次拉取；返回频道列表，失败返回空并给出原因
    func fetchWithCandidates(urls: [String]) async -> (channels: [Channel], errorMessage: String?) {
        guard !urls.isEmpty else {
            return ([], NetworkFetchError.allFailed.errorDescription)
        }
        var lastError: String?
        for url in urls {
            do {
                let body = try await fetch(url: url)
                let parsed = M3UParserService.parse(body)
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
}
