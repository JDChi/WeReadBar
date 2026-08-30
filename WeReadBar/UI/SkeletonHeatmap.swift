import SwiftUI

/// Placeholder heatmap shown while `days` is still loading. Renders the
/// same 53×7 grid shape as `HeatmapView` but with gray placeholder
/// rectangles that pulse in unison.
///
/// Animation is **single global** (one `@State` + one `withAnimation`),
/// not per-cell. Per-cell animations previously generated 371 separate
/// `Animation` specs whose teardown, when data arrived and SwiftUI
/// swapped in the real heatmap, caused a perceptible frame stutter.
///
/// All geometric constants come from `HeatmapLayout` so the layout stays
/// in lock-step with the real heatmap.
struct SkeletonHeatmap: View {
    @State private var pulse: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: HeatmapLayout.sectionSpacing) {
            HeatmapHeader()

            // Reserved month-label band — kept empty so the layout
            // matches the real heatmap's vertical rhythm exactly.
            Color.clear.frame(height: HeatmapLayout.monthLabelHeight)

            HStack(alignment: .top, spacing: HeatmapLayout.weekdayToGridSpacing) {
                WeekdayGutter()

                HStack(alignment: .top, spacing: HeatmapLayout.spacing) {
                    ForEach(0..<HeatmapLayout.columns, id: \.self) { _ in
                        VStack(spacing: HeatmapLayout.spacing) {
                            ForEach(0..<HeatmapLayout.rows, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                                    .fill(Color.gray.opacity(pulse ? 0.10 : 0.45))
                                    .frame(width: HeatmapLayout.cellSize, height: HeatmapLayout.cellSize)
                            }
                        }
                    }
                }
            }
        }
        .frame(width: HeatmapLayout.contentWidth, alignment: .leading)
        // Single global animation: 1.0s ease-in-out, autoreverses, repeats
        // forever. One Animation spec for the entire tree, not 371.
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                pulse.toggle()
            }
        }
    }
}
