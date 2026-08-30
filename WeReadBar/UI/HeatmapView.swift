import SwiftUI

/// GitHub-style heatmap: 53 columns (weeks) × 7 rows (days) = 371 cells.
/// `days` should be length 371, oldest first.
///
/// Layout math for a 480pt popover (content area 456pt):
///   weekday gutter (22pt) + 53 cells × 7pt + 52 gaps × 1pt
///   = 22 + 371 + 52 = 445pt   (11pt breathing room)
struct HeatmapView: View {
    let days: [ReadingDay]

    private let cellSize: CGFloat = 7
    private let spacing: CGFloat = 1
    private let columns = 53
    private let rows = 7
    private let gridSize = 53 * 7  // 371
    private let gutterWidth: CGFloat = 22
    private let monthLabelHeight: CGFloat = 12

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
                        RoundedRectangle(cornerRadius: 1, style: .continuous)
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

    /// Top row: month name shown only in the first column of each new month.
    private func monthLabelsRow(weeks: [[ReadingDay]]) -> some View {
        HStack(spacing: spacing) {
            // Spacer matching the weekday-gutter width.
            Color.clear.frame(width: gutterWidth, height: monthLabelHeight)
            ForEach(0..<columns, id: \.self) { weekIdx in
                Text(monthLabel(for: weeks, weekIdx: weekIdx))
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
                    .frame(width: cellSize, height: monthLabelHeight, alignment: .leading)
                    .fixedSize()
                    .offset(x: spacing * CGFloat(weekIdx))  // account for inter-cell gap
            }
        }
    }

    /// Returns the month abbreviation when this week is the first one in a new
    /// month; otherwise empty string. Uses the week's first non-empty day.
    private func monthLabel(for weeks: [[ReadingDay]], weekIdx: Int) -> String {
        guard let firstDay = weeks[weekIdx].first(where: { $0.date != .distantPast }) else {
            return ""
        }
        // Compare against the previous week's first non-empty day.
        if weekIdx > 0,
           let prevDay = weeks[weekIdx - 1].first(where: { $0.date != .distantPast }) {
            let cal = Calendar.current
            let prevMonth = cal.component(.month, from: prevDay.date)
            let thisMonth = cal.component(.month, from: firstDay.date)
            if prevMonth == thisMonth { return "" }
        }
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f.string(from: firstDay.date)
    }

    /// Mon / Wed / Fri gutter.
    private var weekdayLabels: some View {
        VStack(alignment: .trailing, spacing: spacing) {
            ForEach(0..<rows, id: \.self) { row in
                Text(weekdayLabel(for: row))
                    .font(.system(size: 8))
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
