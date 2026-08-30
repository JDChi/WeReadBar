import Foundation

/// Decoded response from `POST /readdata/detail`.
/// Field names match the WeRead gateway; many are nullable because they
/// only appear in some modes (weekly/monthly/annually/overall).
struct ReadDataResponse: Decodable {
    let errcode: Int?
    let errmsg: String?
    let baseTime: Int?
    let totalReadTime: Int?
    let readDays: Int?
    let dayAverageReadTime: Int?
    let compare: Double?

    /// Bucketed read-time map. Bucket granularity depends on `mode`:
    /// - `weekly` / `monthly`: per-day midnights (UTC+8)
    /// - `annually`: per-month
    /// - `overall`: per-year
    /// Keys are unix timestamps (seconds since epoch, UTC+8 midnight).
    let readTimes: [String: Int]?

    /// Per-day detail. **Conditionally returned** in `annually` mode;
    /// treat absence as "fall back to stitching monthly calls".
    let dailyReadTimes: [String: Int]?

    let readStat: [ReadStatItem]?
    let preferCategory: [PreferCategoryItem]?
    let preferTime: [Int]?
    let preferTimeWord: String?

    /// True iff the server accepted the request.
    var isOK: Bool { errcode == nil || errcode == 0 }
}

struct ReadStatItem: Decodable, Hashable {
    let stat: String
    let counts: String
}

struct PreferCategoryItem: Decodable, Hashable {
    let categoryId: Int?
    let categoryTitle: String?
    let parentCategoryId: Int?
    let parentCategoryTitle: String?
    let readingCount: Int?
    let readingTime: Int?
}
