import SwiftUI

/// (weekIdx, label) tuple for a non-empty month label.
private struct MonthLabelEntry: Identifiable {
    let weekIdx: Int
    let label: String
    var id: Int { weekIdx }
}

/// Maps a user's own reading-duration distribution into four visual steps.
/// A fixed 1–15 minute bucket made most of this account's active days look
/// identical, even when their reading times differed materially.
private struct HeatmapColorScale {
    let first: Int
    let second: Int
    let third: Int

    init(days: [ReadingDay]) {
        let activeSeconds = days
            .map(\.seconds)
            .filter { $0 >= 60 }
            .sorted()

        // With enough reading days, quartiles make the heatmap informative
        // for this account rather than hiding most activity in its lowest
        // fixed-duration bucket. Sparse histories keep predictable cutoffs.
        guard activeSeconds.count >= 8 else {
            first = 5 * 60
            second = 15 * 60
            third = 30 * 60
            return
        }

        first = activeSeconds[(activeSeconds.count - 1) / 4]
        second = activeSeconds[(activeSeconds.count - 1) / 2]
        third = activeSeconds[(activeSeconds.count - 1) * 3 / 4]
    }
}

enum HeatmapPalette {
    /// The neutral cell intentionally keeps the app's original soft gray.
    static let noReading = Color.gray.opacity(0.20)

    /// GitHub-style intensity direction adapted to the WeRead blue brand:
    /// dark mode becomes brighter with activity; light mode becomes deeper.
    static func activityColors(for colorScheme: ColorScheme) -> [Color] {
        switch colorScheme {
        case .dark:
            return [
                Color(red: 0x0B / 255.0, green: 0x5C / 255.0, blue: 0xAB / 255.0), // #0B5CAB
                Color(red: 0x14 / 255.0, green: 0x7D / 255.0, blue: 0xDB / 255.0), // #147DDB
                Color(red: 0x1B / 255.0, green: 0x88 / 255.0, blue: 0xEE / 255.0), // #1B88EE
                Color(red: 0x67 / 255.0, green: 0xB7 / 255.0, blue: 0xFF / 255.0)  // #67B7FF
            ]
        default:
            return [
                Color(red: 0xC8 / 255.0, green: 0xE2 / 255.0, blue: 0xFF / 255.0), // #C8E2FF
                Color(red: 0x83 / 255.0, green: 0xBC / 255.0, blue: 0xF8 / 255.0), // #83BCF8
                Color(red: 0x1B / 255.0, green: 0x88 / 255.0, blue: 0xEE / 255.0), // #1B88EE
                Color(red: 0x0B / 255.0, green: 0x5C / 255.0, blue: 0xAB / 255.0)  // #0B5CAB
            ]
        }
    }
}

/// Shared title and intensity legend for the loaded and loading heatmap.
struct HeatmapHeader: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let colors = HeatmapPalette.activityColors(for: colorScheme)
        HStack(spacing: 6) {
            Text(String(localized: "heatmap.title"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            Text(String(localized: "heatmap.less"))
                .font(Theme.monthLabelFont)
                .foregroundStyle(.tertiary)

            HStack(spacing: 3) {
                ForEach(colors.indices, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(colors[index])
                        .frame(width: HeatmapLayout.cellSize, height: HeatmapLayout.cellSize)
                }
            }

            Text(String(localized: "heatmap.more"))
                .font(Theme.monthLabelFont)
                .foregroundStyle(.tertiary)
        }
        .frame(width: HeatmapLayout.contentWidth, height: HeatmapLayout.headerHeight)
    }
}

/// GitHub-style heatmap. All geometric constants live in `HeatmapLayout`
/// so the layout stays in lock-step with `SkeletonHeatmap`.
/// `days` should be length 371, oldest first.
struct HeatmapView: View {
    let days: [ReadingDay]
    @Environment(\.colorScheme) private var colorScheme

    /// True iff we have at least one real (non-placeholder) day to render.
    /// Used to switch between skeleton and real-heatmap modes.
    private var hasData: Bool {
        days.contains { $0.date != .distantPast }
    }

    var body: some View {
        // Cross-fade between skeleton and real heatmap when `hasData` flips.
        // Wrapping in `Group` is required for `.transition(_:)` to fire — direct
        // `if`/`else` branches inside `body` swap without animation.
        Group {
            if hasData {
                realHeatmap.transition(.opacity)
            } else {
                SkeletonHeatmap()
                    .transition(.opacity)
            }
        }
        .frame(height: HeatmapLayout.totalHeight)
        .animation(.easeInOut(duration: 0.18), value: hasData)
    }

    private var realHeatmap: some View {
        // Pad to exactly 371; missing entries render as empty placeholders.
        let padded: [ReadingDay] = {
            if days.count >= HeatmapLayout.gridSize {
                return Array(days.prefix(HeatmapLayout.gridSize))
            }
            return days + Array(repeating: .empty, count: HeatmapLayout.gridSize - days.count)
        }()

        return VStack(alignment: .leading, spacing: HeatmapLayout.sectionSpacing) {
            let weekColumns = weeks(padded)
            let colorScale = HeatmapColorScale(days: padded)
            HeatmapHeader()
            monthLabelsRow(weeks: weekColumns)
            HStack(alignment: .top, spacing: HeatmapLayout.weekdayToGridSpacing) {
                WeekdayGutter()
                HStack(alignment: .top, spacing: HeatmapLayout.spacing) {
                    // A column is one calendar week, ordered Monday → Sunday.
                    // `LazyVGrid` fills row-first, which made adjacent dates
                    // land 53 cells apart. Rendering explicit week columns
                    // preserves the chronological 7-day grouping above.
                    ForEach(Array(weekColumns.enumerated()), id: \.offset) { _, week in
                        VStack(spacing: HeatmapLayout.spacing) {
                            ForEach(Array(week.enumerated()), id: \.offset) { _, day in
                                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                                    .fill(color(for: day, scale: colorScale))
                                    .frame(width: HeatmapLayout.cellSize, height: HeatmapLayout.cellSize)
                            }
                        }
                    }
                }
            }
        }
        .frame(width: HeatmapLayout.contentWidth, alignment: .leading)
    }

    /// Groups the 371 flat entries into 53 weeks (each = 7 days, oldest first).
    private func weeks(_ padded: [ReadingDay]) -> [[ReadingDay]] {
        var result: [[ReadingDay]] = []
        result.reserveCapacity(HeatmapLayout.columns)
        for w in 0..<HeatmapLayout.columns {
            let start = w * HeatmapLayout.rows
            let end = min(start + HeatmapLayout.rows, padded.count)
            if start < padded.count {
                let slice = Array(padded[start..<end])
                if slice.count < HeatmapLayout.rows {
                    result.append(slice + Array(repeating: .empty, count: HeatmapLayout.rows - slice.count))
                } else {
                    result.append(slice)
                }
            }
        }
        return result
    }

    /// Top row: month name shown only at the leading edge of the first column
    /// of each new month. Empty columns are not rendered (no placeholders).
    /// Labels are positioned with absolute `offset()` so they sit precisely at
    /// the start of their column regardless of label text width.
    private func monthLabelsRow(weeks: [[ReadingDay]]) -> some View {
        let entries = collectMonthLabels(weeks: weeks)
        let totalWidth = monthLabelsRowWidth()

        return ZStack(alignment: .topLeading) {
            Color.clear.frame(height: HeatmapLayout.monthLabelHeight)
            ForEach(entries, id: \.weekIdx) { entry in
                monthLabelView(text: entry.label, weekIdx: entry.weekIdx)
            }
        }
        .frame(width: totalWidth, height: HeatmapLayout.monthLabelHeight)
    }

    /// Total width the month-label row should occupy (= heatmap row width).
    private func monthLabelsRowWidth() -> CGFloat {
        HeatmapLayout.contentWidth
    }

    /// Minimum number of weeks between adjacent month labels to avoid visual overlap.
    /// 3 weeks × 10pt = 30pt of breathing room, comfortably wider than any 3-letter month name.
    private static let minSpacingWeeks = 3

    /// Pre-computed (weekIdx, label) pairs after applying GitHub's algorithm.
    private func collectMonthLabels(weeks: [[ReadingDay]]) -> [MonthLabelEntry] {
        let cal = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        formatter.locale = Locale.current   // "MMM" → "Jan" / "1月" / "1月"

        // Step 1: candidate = first week that contains day-1 of a given month.
        var candidates: [(weekIdx: Int, label: String)] = []
        for weekIdx in 0..<HeatmapLayout.columns {
            for day in weeks[weekIdx] where day.date != .distantPast {
                if cal.component(.day, from: day.date) == 1 {
                    candidates.append((weekIdx, formatter.string(from: day.date)))
                    break  // one label per week max
                }
            }
        }

        // Step 2: greedy minimum-spacing filter.
        var result: [MonthLabelEntry] = []
        var lastWeekIdx = -Self.minSpacingWeeks
        for (weekIdx, label) in candidates {
            if weekIdx - lastWeekIdx >= Self.minSpacingWeeks {
                result.append(MonthLabelEntry(weekIdx: weekIdx, label: label))
                lastWeekIdx = weekIdx
            }
        }
        return result
    }

    /// A single month-label view, positioned at its column's leading edge.
    private func monthLabelView(text: String, weekIdx: Int) -> some View {
        let xOffset = HeatmapLayout.gutterWidth
            + HeatmapLayout.weekdayToGridSpacing
            + CGFloat(weekIdx) * (HeatmapLayout.cellSize + HeatmapLayout.spacing)
        return Text(text)
            .font(Theme.monthLabelFont)
            .foregroundStyle(.tertiary)
            .fixedSize()
            .offset(x: xOffset)
    }

    private func color(for day: ReadingDay, scale: HeatmapColorScale) -> Color {
        guard day.date != .distantPast else { return .clear }
        // GitHub-style four-level contribution intensity, expressed with
        // WeRead blue rather than GitHub green. The relative level comes from
        // this account's reading-time quartiles.
        let colors = HeatmapPalette.activityColors(for: colorScheme)
        switch day.seconds {
        case ..<60:           return HeatmapPalette.noReading
        case ...scale.first:  return colors[0]
        case ...scale.second: return colors[1]
        case ...scale.third:  return colors[2]
        default:              return colors[3]
        }
    }
}
