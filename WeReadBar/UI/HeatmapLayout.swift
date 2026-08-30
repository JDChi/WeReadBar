import SwiftUI

/// Heatmap geometry — cell size, spacing, column count, weekday gutter,
/// month-label band. Used by both `HeatmapView` and `SkeletonHeatmap`.
///
/// Popover-wide layout math (content area = Theme.popoverWidth - 24pt
/// padding × 2):
///   gutterWidth + columns × cellSize + (columns - 1) × spacing
///   = 28 + 53 × 12 + 52 × 1 = 716pt   (target ≤ 696pt)
enum HeatmapLayout {
    static let cellSize: CGFloat = 12
    static let spacing: CGFloat = 1
    static let columns: Int = 53
    static let rows: Int = 7
    static let gridSize: Int = columns * rows  // 371
    static let gutterWidth: CGFloat = 28
    static let monthLabelHeight: CGFloat = 18
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
        // shortWeekdaySymbols is locale-aware: en → "Mon", zh-Hans → "周一",
        // zh-Hant → "週一". Calendar indexes Sunday = 0, so row 0/2/4 map to
        // Monday / Wednesday / Friday in our grid layout.
        let symbols = Calendar.current.shortWeekdaySymbols
        switch row {
        case 0: return symbols[0]
        case 2: return symbols[2]
        case 4: return symbols[4]
        default: return ""
        }
    }
}
