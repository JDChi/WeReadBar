import SwiftUI

/// Heatmap geometry — cell size, spacing, column count, weekday gutter,
/// month-label band. Used by both `HeatmapView` and `SkeletonHeatmap`.
///
/// Popover-wide layout math (content area = Theme.popoverWidth - 14pt
/// padding × 2):
///   gutterWidth + weekdayToGridSpacing + columns × cellSize
///   + (columns - 1) × spacing
///   = 28 + 6 + 53 × 12 + 52 × 1 = 722pt   (target ≤ 752pt)
enum HeatmapLayout {
    static let cellSize: CGFloat = 12
    static let spacing: CGFloat = 1
    static let columns: Int = 53
    static let rows: Int = 7
    static let gridSize: Int = columns * rows  // 371
    static let gutterWidth: CGFloat = 28
    static let weekdayToGridSpacing: CGFloat = 6
    static let sectionSpacing: CGFloat = 2
    static let headerHeight: CGFloat = 16
    static let monthLabelHeight: CGFloat = 18

    static var gridWidth: CGFloat {
        CGFloat(columns) * cellSize + CGFloat(columns - 1) * spacing
    }

    static var contentWidth: CGFloat {
        gutterWidth + weekdayToGridSpacing + gridWidth
    }

    static var totalHeight: CGFloat {
        headerHeight
            + sectionSpacing
            + monthLabelHeight
            + sectionSpacing
            + cellSize * CGFloat(rows)
            + spacing * CGFloat(rows - 1)
    }
}

/// Shared Mon / Wed / Fri gutter used by both the real and skeleton heatmaps.
/// Static text — labels are visible even while the data is loading so the
/// layout reads identically in both states.
struct WeekdayGutter: View {
    var body: some View {
        VStack(alignment: .trailing, spacing: HeatmapLayout.spacing) {
            ForEach(0..<HeatmapLayout.rows, id: \.self) { row in
                Text(label(for: row))
                    .font(Theme.weekdayLabelFont)
                    .foregroundStyle(.tertiary)
                    .frame(
                        width: HeatmapLayout.gutterWidth,
                        height: HeatmapLayout.cellSize,
                        alignment: .trailing
                    )
            }
        }
    }

    private func label(for row: Int) -> String {
        // `shortWeekdaySymbols` is Sunday-first; the heatmap uses Monday-first
        // week columns, independent of the user's firstWeekday preference.
        let symbols = Calendar.current.shortWeekdaySymbols
        switch row {
        case 0: return symbols[1]   // Mon / 周一 / 週一
        case 2: return symbols[3]   // Wed / 周三 / 週三
        case 4: return symbols[5]   // Fri / 周五 / 週五
        default: return ""
        }
    }
}
