import Foundation

/// One calendar day's reading activity.
/// `date` must be normalized to `Calendar.current.startOfDay(for:)`.
struct ReadingDay: Identifiable, Hashable {
    let date: Date
    let seconds: Int

    /// A day counts as "actively read" iff the user spent ≥ 60 s reading.
    /// This matches the server-side `readDays` rule documented in weread-skills.
    var active: Bool { seconds >= 60 }
    var minutes: Int { seconds / 60 }
    var id: Date { date }
}

/// Empty placeholder used to pad the heatmap to a fixed 26×7 = 182 grid.
extension ReadingDay {
    static let empty = ReadingDay(date: .distantPast, seconds: 0)
}
