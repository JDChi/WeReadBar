import Foundation
import SwiftUI
import os

private let wrLog = Logger(subsystem: "com.local.wereadbar", category: "stats")

/// Source of truth for the popover. Owns the network client and orchestrates
/// the heatmap data pipeline (annual → fall back to 7× monthly).
@MainActor
final class StatsStore: ObservableObject {

    // MARK: - Published state (UI-facing)

    /// Calendar days used by the heatmap, oldest first.
    @Published private(set) var days: [ReadingDay] = []
    @Published private(set) var todaySeconds: Int = 0
    @Published private(set) var streak: Int = 0
    @Published private(set) var weekTotalSeconds: Int = 0
    @Published private(set) var shelfCount: Int = 0
    @Published private(set) var currentlyReading: BookSummary? = nil
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var lastError: String? = nil
    @Published var needsAPIKey: Bool = false

    /// True iff `days` has at least one real (non-placeholder) entry.
    /// Independent of `isLoading`: a refresh that hasn't completed yet, or
    /// one that returned no usable data, both leave `hasData == false`.
    var hasData: Bool {
        days.contains { $0.date != .distantPast }
    }

    // MARK: - Dependencies

    private var client: WeReadClient?
    private var refreshTask: Task<Void, Never>?
    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        c.firstWeekday = 2 // Monday
        return c
    }()

    // MARK: - Lifecycle

    /// Bootstrap is invoked explicitly by
    /// `AppDelegate.applicationDidFinishLaunching` so the data pipeline
    /// starts exactly once on launch. No-op init keeps the @MainActor
    /// default-initialiser compatible with the `@StateObject` callers
    /// elsewhere (defensive — currently only AppDelegate owns the store).
    init() {}

    func bootstrap() {
        if let token = TokenStore.load() {
            wrLog.info("bootstrap: UserDefaults has token (len=\(token.count))")
            client = WeReadClient(apiKey: token)
            needsAPIKey = false
            Task { await refresh() }
        } else {
            wrLog.notice("bootstrap: no token found, needsAPIKey=true")
            needsAPIKey = true
        }
    }

    /// Validates a user-supplied token by hitting `/shelf/sync`. Persists on success.
    /// Returns true iff the token was accepted.
    @discardableResult
    func setAPIKey(_ raw: String) async -> Bool {
        let token = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            lastError = String(localized: "error.tokenEmpty")
            return false
        }
        let candidate = WeReadClient(apiKey: token)
        do {
            let shelf = try await candidate.fetchShelf()
            guard shelf.isOK else {
                lastError = shelf.errmsg ?? String(localized: "error.wechatRejected")
                return false
            }
            TokenStore.save(token)
            client = candidate
            needsAPIKey = false
            lastError = nil
            await refresh()
            return true
        } catch {
            lastError = String.localizedStringWithFormat(
                NSLocalizedString("error.authNetwork", comment: ""),
                error.localizedDescription
            )
            return false
        }
    }

    /// Public refresh entry point. Cancels any in-flight refresh first.
    func refresh() async {
        refreshTask?.cancel()
        let task = Task { [weak self] in
            guard let self else { return }
            await self.performRefresh()
        }
        refreshTask = task
        await task.value
    }

    /// Wipes the stored token + local state. For the right-click "Change API key" menu item.
    func clearAPIKey() {
        TokenStore.clear()
        client = nil
        needsAPIKey = true
        days = []
        todaySeconds = 0
        streak = 0
        weekTotalSeconds = 0
        shelfCount = 0
        currentlyReading = nil
        lastError = nil
    }

    // MARK: - Pipeline

    private func performRefresh() async {
        guard let client else {
            wrLog.error("performRefresh: client is nil")
            return
        }
        isLoading = true
        defer { isLoading = false }
        wrLog.info("performRefresh: starting")

        do {
            try Task.checkCancellation()

            // Kick off shelf + annual concurrently.
            async let shelfAsync = client.fetchShelf()
            async let annualAsync = client.fetchAnnual(
                baseTime: WeReadClient.yearStartUTC8(for: Date())
            )

            let shelf = try await shelfAsync
            wrLog.info("performRefresh: shelf isOK=\(shelf.isOK, privacy: .public), books=\(shelf.books?.count ?? 0, privacy: .public), mp=\(shelf.mp != nil, privacy: .public)")
            guard shelf.isOK else {
                lastError = shelf.errmsg ?? String(localized: "error.wechatRejected")
                return
            }
            shelfCount = shelf.totalCount
            currentlyReading = shelf.firstReading
            if let reading = currentlyReading, !reading.bookId.isEmpty {
                do {
                    let progress = try await client.fetchBookProgress(bookId: reading.bookId)
                    try Task.checkCancellation()
                    if progress.isOK, let percent = progress.book?.progress {
                        currentlyReading = reading.replacingProgress(with: percent)
                    } else {
                        wrLog.warning("performRefresh: current-book progress unavailable")
                    }
                } catch is CancellationError {
                    throw CancellationError()
                } catch let error as URLError where error.code == .cancelled {
                    throw error
                } catch {
                    // Keep the current book visible when its optional progress lookup fails.
                    wrLog.warning("performRefresh: current-book progress failed: \(error.localizedDescription, privacy: .public)")
                }
            }

            let annual = try await annualAsync
            wrLog.info("performRefresh: annual isOK=\(annual.isOK, privacy: .public), dailyReadTimes=\(annual.dailyReadTimes?.count ?? -1, privacy: .public), readTimes=\(annual.readTimes?.count ?? -1, privacy: .public)")
            guard annual.isOK else {
                lastError = annual.errmsg ?? String(localized: "error.wechatGeneric")
                return
            }

            let resolved = try await resolveHeatmap(annual: annual, client: client)
            try Task.checkCancellation()
            let nonZero = resolved.filter { $0.seconds > 0 }.count
            wrLog.info("performRefresh: built \(resolved.count) days, \(nonZero) non-zero")
            if let firstNonZero = resolved.first(where: { $0.seconds > 0 }) {
                wrLog.info("  first non-zero: date=\(firstNonZero.date, privacy: .public), seconds=\(firstNonZero.seconds, privacy: .public)")
            }
            days = resolved
            todaySeconds = secondsForToday(resolved)
            streak = computeStreak(resolved)
            weekTotalSeconds = computeWeekTotal(resolved)
            lastError = nil
        } catch is CancellationError {
            wrLog.info("performRefresh: cancelled")
        } catch let error as URLError where error.code == .cancelled {
            wrLog.info("performRefresh: URL cancelled")
        } catch {
            wrLog.error("performRefresh: error \(error.localizedDescription, privacy: .public)")
            lastError = error.localizedDescription
        }
    }

    /// Resolves a 53-week [ReadingDay] grid of length 371.
    /// Strategy:
    /// 1. If annual `dailyReadTimes` is present and non-empty, use it.
    /// 2. Otherwise, stitch 13 monthly calls (last 13 months' worth of per-day `readTimes`).
    private func resolveHeatmap(
        annual: ReadDataResponse,
        client: WeReadClient
    ) async throws -> [ReadingDay] {
        if ProcessInfo.processInfo.environment["WEREADBAR_FORCE_MONTHLY"] == "1" {
            return try await stitchMonthly(client: client)
        }
        if let drt = annual.dailyReadTimes, !drt.isEmpty {
            return buildDays(from: drt)
        }
        return try await stitchMonthly(client: client)
    }

    private func stitchMonthly(client: WeReadClient) async throws -> [ReadingDay] {
        let now = Date()
        var bag: [String: Int] = [:]
        let origin = firstOfMonth(now)
        // 53 weeks ≈ 13 months → walk back 12 prior + current.
        for offset in stride(from: -12, through: 0, by: 1) {
            try Task.checkCancellation()
            guard let monthDate = calendar.date(byAdding: .month, value: offset, to: origin) else {
                wrLog.warning("  stitch: could not compute month for offset=\(offset, privacy: .public)")
                continue
            }
            let baseTime = WeReadClient.monthStartUTC8(for: monthDate)
            let res = try await client.fetchMonthly(baseTime: baseTime)
            // monthly mode: prefer `dailyReadTimes`, fall back to `readTimes`.
            let src = res.dailyReadTimes ?? res.readTimes ?? [:]
            wrLog.info("  stitch monthly baseTime=\(baseTime, privacy: .public): got \(src.count) keys")
            for (k, v) in src { bag[k, default: 0] += v }
        }
        wrLog.info("stitchMonthly: bag has \(bag.count) unique keys")
        if let firstKey = bag.keys.sorted().first {
            wrLog.info("  earliest key: \(firstKey, privacy: .public) -> \(bag[firstKey] ?? 0, privacy: .public)s")
        }
        return buildDays(from: bag)
    }

    private func firstOfMonth(_ date: Date) -> Date {
        let comps = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: comps) ?? date
    }

    /// Builds 53 Monday–Sunday week columns (371 days), oldest first.
    /// The final column is the current calendar week, so its future dates are
    /// retained as zero-second cells. This keeps every row aligned with the
    /// weekday gutter regardless of which day refresh happens.
    /// `internal` (not private) so WeReadBarTests can call it directly via
    /// `@testable import WeReadBar`.
    func buildDays(from dict: [String: Int]) -> [ReadingDay] {
        let today = calendar.startOfDay(for: Date())
        guard let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start,
              let gridStart = calendar.date(
                  byAdding: .weekOfYear,
                  value: -(HeatmapLayout.columns - 1),
                  to: currentWeekStart
              ) else {
            return []
        }
        var out: [ReadingDay] = []
        out.reserveCapacity(371)
        for offset in 0..<HeatmapLayout.gridSize {
            guard let d = calendar.date(byAdding: .day, value: offset, to: gridStart) else {
                continue
            }
            let key = String(Int(d.timeIntervalSince1970))
            let secs = dict[key] ?? 0
            out.append(ReadingDay(date: d, seconds: secs))
        }
        return out
    }

    // MARK: - Derived

    /// Internal (not private) for `@testable import` unit tests.
    func secondsForToday(_ days: [ReadingDay]) -> Int {
        let today = calendar.startOfDay(for: Date())
        return days.first(where: { $0.date == today })?.seconds ?? 0
    }

    /// Streak = number of consecutive days ending today with `seconds >= 60`.
    /// If today has no activity yet (not yet tallied by the server), start from yesterday.
    /// Internal (not private) for `@testable import` unit tests.
    func computeStreak(_ days: [ReadingDay]) -> Int {
        let byDay = Dictionary(uniqueKeysWithValues: days.map { ($0.date, $0.seconds) })
        var cursor = calendar.startOfDay(for: Date())
        var streak = 0

        // Today may not be tallied yet; if so, skip it and walk from yesterday.
        if (byDay[cursor] ?? 0) < 60 {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                return 0
            }
            cursor = yesterday
        }

        while (byDay[cursor] ?? 0) >= 60 {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                break
            }
            cursor = prev
        }
        return streak
    }

    /// Sum of `seconds` for the current calendar week (Mon-Sun) containing today.
    /// Internal (not private) for `@testable import` unit tests.
    func computeWeekTotal(_ days: [ReadingDay]) -> Int {
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let firstWeekday = calendar.firstWeekday
        let daysSinceWeekStart = (weekday - firstWeekday + 7) % 7
        guard let weekStart = calendar.date(byAdding: .day, value: -daysSinceWeekStart, to: today) else {
            return 0
        }
        return days
            .filter { $0.date >= weekStart }
            .reduce(0) { $0 + $1.seconds }
    }
}
