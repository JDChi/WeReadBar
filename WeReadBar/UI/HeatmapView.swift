import SwiftUI

/// GitHub-style heatmap: 26 columns (weeks) × 7 rows (days) = 182 cells.
/// `days` should be length 182, oldest first.
///
/// Layout math for a 340pt popover (content area 316pt):
///   weekday gutter (18pt) + 26 cells × 9pt + 25 gaps × 2pt
///   = 18 + 234 + 50 = 302pt   (14pt breathing room)
struct HeatmapView: View {
    let days: [ReadingDay]

    private let cellSize: CGFloat = 9
    private let spacing: CGFloat = 2
    private let columns = 26
    private let rows = 7
    private let gridSize = 26 * 7  // 182
    private let gutterWidth: CGFloat = 18

    var body: some View {
        // Pad to exactly 182; missing entries render as empty placeholders.
        let padded: [ReadingDay] = {
            if days.count >= gridSize {
                return Array(days.prefix(gridSize))
            }
            return days + Array(repeating: .empty, count: gridSize - days.count)
        }()

        HStack(alignment: .top, spacing: spacing) {
            weekdayLabels
            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(cellSize), spacing: spacing), count: columns),
                alignment: .leading,
                spacing: spacing
            ) {
                ForEach(0..<gridSize, id: \.self) { idx in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(color(for: padded[idx]))
                        .frame(width: cellSize, height: cellSize)
                }
            }
        }
        .frame(height: cellSize * CGFloat(rows) + spacing * CGFloat(rows - 1))
    }

    /// Mon / Wed / Fri gutter, vertically aligned with rows 0 / 2 / 4.
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
        // Row 0 = top (Monday in our layout, since oldest day is at top).
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
