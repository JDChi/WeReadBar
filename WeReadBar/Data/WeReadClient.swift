import Foundation

/// Transport-only client for the WeRead Agent API Gateway.
/// All requests POST to the same endpoint with `api_name` and `skill_version`.
actor WeReadClient {
    private static let baseURL = URL(string: "https://i.weread.qq.com/api/agent/gateway")!
    private static let skillVersion = "1.0.4"

    private let apiKey: String
    private let session: URLSession
    private let decoder: JSONDecoder

    init(apiKey: String) {
        self.apiKey = apiKey
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 15
        cfg.waitsForConnectivity = false
        cfg.httpMaximumConnectionsPerHost = 4
        self.session = URLSession(configuration: cfg)
        self.decoder = JSONDecoder()
    }

    /// Fetches the full shelf (no params; auth identifies user).
    func fetchShelf() async throws -> ShelfResponse {
        let data = try await post(apiName: "/shelf/sync")
        return try decoder.decode(ShelfResponse.self, from: data)
    }

    /// Calendar week (Mon–Sun) containing today.
    func fetchWeekly() async throws -> ReadDataResponse {
        let data = try await post(apiName: "/readdata/detail", params: ["mode": "weekly"])
        return try decoder.decode(ReadDataResponse.self, from: data)
    }

    /// Month containing the calendar date for `baseTime` (UTC+8 midnight).
    /// NB: the server **ignores** `year`/`month` params; `baseTime` is the only way
    /// to query a historical month.
    func fetchMonthly(baseTime: Int) async throws -> ReadDataResponse {
        let data = try await post(
            apiName: "/readdata/detail",
            params: ["mode": "monthly", "baseTime": baseTime]
        )
        return try decoder.decode(ReadDataResponse.self, from: data)
    }

    /// Year containing the calendar date for `baseTime` (UTC+8 Jan-1).
    func fetchAnnual(baseTime: Int) async throws -> ReadDataResponse {
        let data = try await post(
            apiName: "/readdata/detail",
            params: ["mode": "annually", "baseTime": baseTime]
        )
        return try decoder.decode(ReadDataResponse.self, from: data)
    }

    /// All-time summary (bucketed per year).
    func fetchOverall() async throws -> ReadDataResponse {
        let data = try await post(apiName: "/readdata/detail", params: ["mode": "overall"])
        return try decoder.decode(ReadDataResponse.self, from: data)
    }

    // MARK: - Private

    private func post(apiName: String, params: [String: Any] = [:]) async throws -> Data {
        var body: [String: Any] = [
            "api_name": apiName,
            "skill_version": Self.skillVersion
        ]
        for (k, v) in params { body[k] = v }
        var req = URLRequest(url: Self.baseURL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw URLError(.badServerResponse, userInfo: ["statusCode": code])
        }
        return data
    }
}

// MARK: - baseTime helpers

extension WeReadClient {
    /// UTC+8 midnight of the first day of the month containing `date`, as a Unix timestamp.
    static func monthStartUTC8(for date: Date) -> Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let comps = cal.dateComponents([.year, .month], from: date)
        let firstOfMonth = cal.date(from: comps)!
        return Int(firstOfMonth.timeIntervalSince1970)
    }

    /// UTC+8 midnight of January 1 of the year containing `date`, as a Unix timestamp.
    static func yearStartUTC8(for date: Date) -> Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let comps = cal.dateComponents([.year], from: date)
        let jan1 = cal.date(from: comps)!
        return Int(jan1.timeIntervalSince1970)
    }
}
