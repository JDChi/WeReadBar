import SwiftUI

/// (weekIdx, label) tuple for a non-empty month label.
private struct MonthLabelEntry: Identifiable {
    let weekIdx: Int
    let label: String
    var id: Int { weekIdx }
}

/// GitHub-style heatmap: 53 columns (weeks) × 7 rows (days) = 371 cells.
/// `days` should be length 371, oldest first.
///
/// Layout math for a 600pt popover (content area 576pt):
///   weekday gutter (26pt) + 53 cells × 9pt + 52 gaps × 1pt
///   = 26 + 477 + 52 = 555pt   (21pt breathing room)
struct HeatmapView: View {
    let days: [ReadingDay]

    private let cellSize: CGFloat = 9
    private let spacing: CGFloat = 1
    private let columns = 53
    private let rows = 7
    private let gridSize = 53 * 7  // 371
    private let gutterWidth: CGFloat = 26
    private let monthLabelHeight: CGFloat = 14

    var body: some View {
        // Pad to exactly 371; missing entries render as empty placeholders.
        let padded: [ReadingDay] = {
            if days.count >= gridSize {
                return Array(days.prefix(gridSize))
            }
            return days + Array(repeating: .empty, count: gridSize - days.count)
        }()

        VStack(alignment: .leading, spacing: 2) {
            monthLabelsRow(weeks: weeks(padded))
            HStack(alignment: .top, spacing: spacing) {
                weekdayLabels
                LazyVGrid(
                    columns: Array(repeating: GridItem(.fixed(cellSize), spacing: spacing), count: columns),
                    alignment: .leading,
                    spacing: spacing
                ) {
                    ForEach(0..<gridSize, id: \.self) { idx in
                        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                            .fill(color(for: padded[idx]))
                            .frame(width: cellSize, height: cellSize)
                    }
                }
            }
        }
        .frame(height: monthLabelHeight + cellSize * CGFloat(rows) + spacing * CGFloat(rows - 1))
    }

    /// Groups the 371 flat entries into 53 weeks (each = 7 days, oldest first).
    private func weeks(_ padded: [ReadingDay]) -> [[ReadingDay]] {
        var result: [[ReadingDay]] = []
        result.reserveCapacity(columns)
        for w in 0..<columns {
            let start = w * rows
            let end = min(start + rows, padded.count)
            if start < padded.count {
                let slice = Array(padded[start..<end])
                if slice.count < rows {
                    result.append(slice + Array(repeating: .empty, count: rows - slice.count))
                } else {
                    result.append(slice)
                }
            }
        }
        return result
    }

    /// Top row: month name shown only at the column whose week contains the
    /// 1st of a month, then filtered by a minimum spacing to prevent overlap.
    /// Algorithm mirrors GitHub's contribution graph:
    ///   1. Find each week that contains day-1 of some month.
    ///   2. Greedily keep labels that are at least `minSpacingWeeks` apart.
    private func monthLabelsRow(weeks: [[ReadingDay]]) -> some View {
        let entries = collectMonthLabels(weeks: weeks)
        let totalWidth = monthLabelsRowWidth()

        return ZStack(alignment: .topLeading) {
            Color.clear.frame(height: monthLabelHeight)
            ForEach(entries, id: \.weekIdx) { entry in
                monthLabelView(text: entry.label, weekIdx: entry.weekIdx)
            }
        }
        .frame(width: totalWidth, height: monthLabelHeight)
    }

    /// Total width the month-label row should occupy (= heatmap row width).
    private func monthLabelsRowWidth() -> CGFloat {
        return gutterWidth + spacing + CGFloat(columns) * cellSize + CGFloat(columns - 1) * spacing
    }

    /// Minimum number of weeks between adjacent month labels to avoid visual overlap.
    /// 3 weeks × 10pt = 30pt of breathing room, comfortably wider than any 3-letter month name.
    private static let minSpacingWeeks = 3

    /// Pre-computed (weekIdx, label) pairs after applying GitHub's algorithm.
    private func collectMonthLabels(weeks: [[ReadingDay]]) -> [MonthLabelEntry] {
        let cal = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"

        // Step 1: candidate = first week that contains day-1 of a given month.
        var candidates: [(weekIdx: Int, label: String)] = []
        for weekIdx in 0..<columns {
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
        let xOffset = gutterWidth + spacing + CGFloat(weekIdx) * (cellSize + spacing)
        return Text(text)
            .font(.system(size: 9))
            .foregroundStyle(.tertiary)
            .fixedSize()
            .offset(x: xOffset)
    }

    /// Mon / Wed / Fri gutter.
    private var weekdayLabels: some View {
        VStack(alignment: .trailing, spacing: spacing) {
            ForEach(0..<rows, id: \.self) { row in
                Text(weekdayLabel(for: row))
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .frame(width: gutterWidth, height: cellSize, alignment: .trailing)
            }
        }
    }

    private func weekdayLabel(for row: Int) -> String {
        switch row {
        case 0: return "Mon"
        case 2: return "Wed"
        case 4: return "Fri"
        default: return ""
        }
    }

    private func color(for day: ReadingDay) -> Color {
        guard day.date != .distantPast else { return .clear }
        let m = day.minutes
        switch m {
        case 0:        return Color.gray.opacity(0.12)
        case 1...15:   return Self.brand.opacity(0.35)
        case 16...45:  return Self.brand.opacity(0.65)
        default:       return Self.brand.opacity(0.95)
        }
    }

    /// WeRead brand blue: #1b88ee (RGB 27 / 136 / 238).
    /// Primary theme color extracted from weread.qq.com's --WR_BC0 CSS variable.
    private static let brand = Color(
        red: 0x1b / 255.0,
        green: 0x88 / 255.0,
        blue: 0xee / 255.0
    )
}
