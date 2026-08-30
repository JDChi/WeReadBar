import SwiftUI

/// Single source of truth for the heatmap's geometric constants. Used by
/// both `HeatmapView` and `SkeletonHeatmap` so changes propagate to both.
///
/// Layout math for a 600pt popover (content area 576pt):
///   gutterWidth (26pt) + 53 cells × 9pt + 52 gaps × 1pt
///   = 26 + 477 + 52 = 555pt   (21pt breathing room)
enum HeatmapLayout {
    static let cellSize: CGFloat = 9
    static let spacing: CGFloat = 1
    static let columns: Int = 53
    static let rows: Int = 7
    static let gridSize: Int = columns * rows  // 371
    static let gutterWidth: CGFloat = 26
    static let monthLabelHeight: CGFloat = 14
}

/// Shared Mon / Wed / Fri gutter used by both the real and skeleton heatmaps.
/// Static text — labels are visible even while the data is loading so the
/// layout reads identically in both states.
struct WeekdayGutter: View {
    var body: some View {
        VStack(alignment: .trailing, spacing: HeatmapLayout.spacing) {
            ForEach(0..<HeatmapLayout.rows, id: \.self) { row in
                Text(label(for: row))
                    .font(.system(size: 9))
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
