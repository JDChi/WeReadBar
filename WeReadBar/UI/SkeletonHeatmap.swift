import SwiftUI

/// Placeholder heatmap shown while `days` is still loading. Renders the
/// same 53×7 grid shape as `HeatmapView` but with gray placeholder
/// rectangles that pulse, so the user sees the expected layout instead
/// of an empty area during the first refresh / cold start.
struct SkeletonHeatmap: View {
    let cellSize: CGFloat
    let spacing: CGFloat
    let columns: Int
    let rows: Int
    let gutterWidth: CGFloat
    let monthLabelHeight: CGFloat

    @State private var pulse: Bool = false

    private var gridSize: Int { columns * rows }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Reserved month-label band — kept empty so the layout
            // matches the real heatmap's vertical rhythm exactly.
            Color.clear.frame(height: monthLabelHeight)

            HStack(alignment: .top, spacing: spacing) {
                weekdayLabels

                LazyVGrid(
                    columns: Array(repeating: GridItem(.fixed(cellSize), spacing: spacing), count: columns),
                    alignment: .leading,
                    spacing: spacing
                ) {
                    ForEach(0..<gridSize, id: \.self) { idx in
                        // Wider opacity range (0.08 ↔ 0.55) and a per-cell
                        // delay produces a left-to-right "wave" instead of
                        // a uniform blink, which reads as clearly alive.
                        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                            .fill(Color.gray.opacity(pulse ? 0.08 : 0.55))
                            .frame(width: cellSize, height: cellSize)
                            .animation(
                                .easeInOut(duration: 0.85)
                                    .delay(Double(idx % columns) * 0.012),
                                value: pulse
                            )
                    }
                }
            }
        }
        .onAppear {
            // 0.85s ease-in-out, ~1.7s full cycle, repeating forever.
            withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
                pulse.toggle()
            }
        }
    }

    /// Mon / Wed / Fri gutter — same styling as `HeatmapView.weekdayLabels`
    /// so the layout and font weight match exactly.
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
}

