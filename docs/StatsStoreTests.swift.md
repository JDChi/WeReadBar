import XCTest
@testable import WeReadBar

/// Tests for `StatsStore`'s pure helpers. These run without a network
/// or Keychain — they exercise the local data transformations that
/// underpin the heatmap and stat tiles.
@MainActor
final class StatsStoreTests: XCTestCase {

    // MARK: - Helpers

    /// Build a StatsStore that has never called `bootstrap()` (no Keychain
    /// access). The class only needs the calendar and a fresh days array.
    private func makeStore() -> StatsStore {
        StatsStore()
    }

    /// Build a single ReadingDay at the given offset from today (negative
    /// = in the past, 0 = today), in the user's UTC+8 calendar.
    private func day(_ seconds: Int, daysAgo: Int) -> ReadingDay {
        let cal = Calendar(identifier: .gregorian)
        var c = cal
        c.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let today = c.startOfDay(for: Date())
        let d = c.date(byAdding: .day, value: -daysAgo, to: today)!
        return ReadingDay(date: d, seconds: seconds)
    }

    /// Unix timestamp (seconds) at UTC+8 midnight of the given offset day.
    private func utc8Midnight(daysAgo: Int) -> String {
        let cal = Calendar(identifier: .gregorian)
        var c = cal
        c.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let today = c.startOfDay(for: Date())
        let d = c.date(byAdding: .day, value: -daysAgo, to: today)!
        return String(Int(d.timeIntervalSince1970))
    }

    // MARK: - buildDays

    func test_buildDays_returnsEmptyForEmptyDict() {
        let store = makeStore()
        let result = store.buildDays(from: [:])
        XCTAssertEqual(result.count, HeatmapLayout.gridSize, "should still produce 371 placeholder days")
        XCTAssertTrue(result.allSatisfy { $0.seconds == 0 }, "all days should be 0 when dict is empty")
        XCTAssertTrue(result.allSatisfy { $0.date != .distantPast })
    }

    func test_buildDays_pullsSecondsFromMatchingKey() {
        let store = makeStore()
        let k = utc8Midnight(daysAgo: 5)
        let result = store.buildDays(from: [k: 1234])
        let match = result.first { String(Int($0.date.timeIntervalSince1970)) == k }
        XCTAssertEqual(match?.seconds, 1234, "the day matching the bag key should have the right seconds")
    }

    func test_buildDays_leavesNonMatchingDaysAtZero() {
        let store = makeStore()
        let result = store.buildDays(from: [utc8Midnight(daysAgo: 100): 999])
        // Only one day should be non-zero; the rest stay at 0.
        let nonZero = result.filter { $0.seconds > 0 }
        XCTAssertEqual(nonZero.count, 1)
        XCTAssertEqual(nonZero.first?.seconds, 999)
    }

    func test_buildDays_ordersOldestFirst() {
        let store = makeStore()
        let result = store.buildDays(from: [:])
        // Result[0] is oldest (offset 182), result[370] is today (offset 0).
        let cal = Calendar(identifier: .gregorian)
        var c = cal
        c.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let today = c.startOfDay(for: Date())
        let expectedOldest = c.date(byAdding: .day, value: -(HeatmapLayout.gridSize - 1), to: today)!
        XCTAssertEqual(result.first?.date, expectedOldest, "oldest day at index 0")
        XCTAssertEqual(result.last?.date, today, "today at last index")
    }

    // MARK: - secondsForToday

    func test_secondsForToday_findsToday() {
        let store = makeStore()
        let days = [day(777, daysAgo: 1), day(0, daysAgo: 0), day(123, daysAgo: 2)]
        XCTAssertEqual(store.secondsForToday(days), 0, "today's slot has 0s in this fixture")
    }

    func test_secondsForToday_returnsZeroWhenTodayMissing() {
        let store = makeStore()
        let days = [day(100, daysAgo: 1), day(200, daysAgo: 2)]
        XCTAssertEqual(store.secondsForToday(days), 0)
    }

    // MARK: - computeStreak

    func test_streak_isZeroWhenTodayEmpty() {
        let store = makeStore()
        let days = [
            day(0, daysAgo: 0),    // today — empty, breaks streak
            day(120, daysAgo: 1),
            day(120, daysAgo: 2)
        ]
        XCTAssertEqual(store.computeStreak(days), 0, "today empty → start from yesterday")
    }

    func test_streak_walksBackFromYesterdayWhenTodayEmpty() {
        let store = makeStore()
        let days = [
            day(0, daysAgo: 0),    // today empty
            day(120, daysAgo: 1),  // active
            day(120, daysAgo: 2),  // active
            day(120, daysAgo: 3),  // active
            day(0, daysAgo: 4)     // inactive, breaks
        ]
        XCTAssertEqual(store.computeStreak(days), 3)
    }

    func test_streak_countsConsecutiveActiveDays() {
        let store = makeStore()
        let days = [
            day(120, daysAgo: 0),
            day(120, daysAgo: 1),
            day(120, daysAgo: 2),
            day(120, daysAgo: 3),
            day(0, daysAgo: 4)
        ]
        XCTAssertEqual(store.computeStreak(days), 4)
    }

    func test_streak_treatsBelow60SecondsAsInactive() {
        let store = makeStore()
        let days = [
            day(120, daysAgo: 0),
            day(59, daysAgo: 1),    // just below threshold
            day(120, daysAgo: 2)
        ]
        XCTAssertEqual(store.computeStreak(days), 1, "59s is below the 60s active-day threshold")
    }

    func test_streak_isZeroOnEmptyArray() {
        let store = makeStore()
        XCTAssertEqual(store.computeStreak([]), 0)
    }

    // MARK: - computeWeekTotal

    func test_weekTotal_sumsCurrentWeekOnly() {
        let store = makeStore()
        // Fixture: today=Sun, 6 days ago = Mon (start of week).
        // Day offsets from today (today is 0):
        //   Mon=6, Tue=5, Wed=4, Thu=3, Fri=2, Sat=1, Sun=0
        let days = [
            day(300, daysAgo: 6),   // Mon — in week
            day(400, daysAgo: 5),   // Tue — in week
            day(500, daysAgo: 4),   // Wed — in week
            day(600, daysAgo: 3),   // Thu — in week
            day(700, daysAgo: 2),   // Fri — in week
            day(800, daysAgo: 1),   // Sat — in week
            day(900, daysAgo: 0),   // Sun (today) — in week
        ]
        let total = days.prefix(7).reduce(0) { $0 + $1.seconds }
        XCTAssertEqual(store.computeWeekTotal(days), total)
    }

    func test_weekTotal_excludesLastWeek() {
        let store = makeStore()
        let days = [
            day(9999, daysAgo: 7),  // last week's Sunday
            day(100, daysAgo: 0)    // this week
        ]
        XCTAssertEqual(store.computeWeekTotal(days), 100)
    }

    func test_weekTotal_isZeroOnEmpty() {
        let store = makeStore()
        XCTAssertEqual(store.computeWeekTotal([]), 0)
    }
}
