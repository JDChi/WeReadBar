import SwiftUI

/// Placeholder heatmap shown while `days` is still loading. Renders the
/// same 53×7 grid shape as `HeatmapView` but with gray placeholder
/// rectangles that pulse in unison.
///
/// Animation is **single global** (one `@State` + one `withAnimation`),
/// not per-cell. Per-cell animations previously generated 371 separate
/// `Animation` specs whose teardown, when data arrived and SwiftUI
/// swapped in the real heatmap, caused a perceptible frame stutter.
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
                    ForEach(0..<gridSize, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                            .fill(Color.gray.opacity(pulse ? 0.10 : 0.45))
                            .frame(width: cellSize, height: cellSize)
                    }
                }
            }
        }
        // Single global animation: 1.0s ease-in-out, autoreverses, repeats
        // forever. One Animation spec for the entire tree, not 371.
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
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


