import SwiftUI

/// Placeholder heatmap shown while `days` is still loading. Renders the
/// same 53×7 grid shape as `HeatmapView` but with gray placeholder
/// rectangles that gently pulse, so the user sees the expected layout
/// instead of an empty area during the first refresh / cold start.
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
                // Reserved weekday gutter
                Color.clear.frame(width: gutterWidth)

                LazyVGrid(
                    columns: Array(repeating: GridItem(.fixed(cellSize), spacing: spacing), count: columns),
                    alignment: .leading,
                    spacing: spacing
                ) {
                    ForEach(0..<gridSize, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                            .fill(Color.gray.opacity(pulse ? 0.10 : 0.22))
                            .frame(width: cellSize, height: cellSize)
                    }
                }
            }
        }
        .onAppear {
            // Gentle ~1.2s ease-in-out pulse, repeating forever.
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulse.toggle()
            }
        }
    }
}
