import SwiftUI

/// (weekIdx, label) tuple for a non-empty month label.
private struct MonthLabelEntry: Identifiable {
    let weekIdx: Int
    let label: String
    var id: Int { weekIdx }
}

/// GitHub-style heatmap. All geometric constants live in `HeatmapLayout`
/// so the layout stays in lock-step with `SkeletonHeatmap`.
/// `days` should be length 371, oldest first.
struct HeatmapView: View {
    let days: [ReadingDay]

    /// True iff we have at least one real (non-placeholder) day to render.
    /// Used to switch between skeleton and real-heatmap modes.
    private var hasData: Bool {
        days.contains { $0.date != .distantPast }
    }

    var body: some View {
        // Cross-fade between skeleton and real heatmap when `hasData` flips.
        // Wrapping in `Group` is required for `.transition(_:)` to fire — direct
        // `if`/`else` branches inside `body` swap without animation.
        Group {
            if hasData {
                realHeatmap.transition(.opacity)
            } else {
                SkeletonHeatmap()
                    .transition(.opacity)
            }
        }
        .frame(
            height: HeatmapLayout.monthLabelHeight
                + HeatmapLayout.cellSize * CGFloat(HeatmapLayout.rows)
                + HeatmapLayout.spacing * CGFloat(HeatmapLayout.rows - 1)
        )
        .animation(.easeInOut(duration: 0.18), value: hasData)
    }

    private var realHeatmap: some View {
        // Pad to exactly 371; missing entries render as empty placeholders.
        let padded: [ReadingDay] = {
            if days.count >= HeatmapLayout.gridSize {
                return Array(days.prefix(HeatmapLayout.gridSize))
            }
            return days + Array(repeating: .empty, count: HeatmapLayout.gridSize - days.count)
        }()

        return VStack(alignment: .leading, spacing: 2) {
            monthLabelsRow(weeks: weeks(padded))
            HStack(alignment: .top, spacing: HeatmapLayout.spacing) {
                WeekdayGutter()
                LazyVGrid(
                    columns: Array(
                        repeating: GridItem(.fixed(HeatmapLayout.cellSize), spacing: HeatmapLayout.spacing),
                        count: HeatmapLayout.columns
                    ),
                    alignment: .leading,
                    spacing: HeatmapLayout.spacing
                ) {
                    ForEach(0..<HeatmapLayout.gridSize, id: \.self) { idx in
                        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                            .fill(color(for: padded[idx]))
                            .frame(width: HeatmapLayout.cellSize, height: HeatmapLayout.cellSize)
                    }
                }
            }
        }
    }

    /// Groups the 371 flat entries into 53 weeks (each = 7 days, oldest first).
    private func weeks(_ padded: [ReadingDay]) -> [[ReadingDay]] {
        var result: [[ReadingDay]] = []
        result.reserveCapacity(HeatmapLayout.columns)
        for w in 0..<HeatmapLayout.columns {
            let start = w * HeatmapLayout.rows
            let end = min(start + HeatmapLayout.rows, padded.count)
            if start < padded.count {
                let slice = Array(padded[start..<end])
                if slice.count < HeatmapLayout.rows {
                    result.append(slice + Array(repeating: .empty, count: HeatmapLayout.rows - slice.count))
                } else {
                    result.append(slice)
                }
            }
        }
        return result
    }

    /// Top row: month name shown only at the leading edge of the first column
    /// of each new month. Empty columns are not rendered (no placeholders).
    /// Labels are positioned with absolute `offset()` so they sit precisely at
    /// the start of their column regardless of label text width.
    private func monthLabelsRow(weeks: [[ReadingDay]]) -> some View {
        let entries = collectMonthLabels(weeks: weeks)
        let totalWidth = monthLabelsRowWidth()

        return ZStack(alignment: .topLeading) {
            Color.clear.frame(height: HeatmapLayout.monthLabelHeight)
            ForEach(entries, id: \.weekIdx) { entry in
                monthLabelView(text: entry.label, weekIdx: entry.weekIdx)
            }
        }
        .frame(width: totalWidth, height: HeatmapLayout.monthLabelHeight)
    }

    /// Total width the month-label row should occupy (= heatmap row width).
    private func monthLabelsRowWidth() -> CGFloat {
        return HeatmapLayout.gutterWidth
            + HeatmapLayout.spacing
            + CGFloat(HeatmapLayout.columns) * HeatmapLayout.cellSize
            + CGFloat(HeatmapLayout.columns - 1) * HeatmapLayout.spacing
    }

    /// Minimum number of weeks between adjacent month labels to avoid visual overlap.
    /// 3 weeks × 10pt = 30pt of breathing room, comfortably wider than any 3-letter month name.
    private static let minSpacingWeeks = 3

    /// Pre-computed (weekIdx, label) pairs after applying GitHub's algorithm.
    private func collectMonthLabels(weeks: [[ReadingDay]]) -> [MonthLabelEntry] {
        let cal = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        formatter.locale = Locale.current   // "MMM" → "Jan" / "1月" / "1月"

        // Step 1: candidate = first week that contains day-1 of a given month.
        var candidates: [(weekIdx: Int, label: String)] = []
        for weekIdx in 0..<HeatmapLayout.columns {
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
        let xOffset = HeatmapLayout.gutterWidth
            + HeatmapLayout.spacing
            + CGFloat(weekIdx) * (HeatmapLayout.cellSize + HeatmapLayout.spacing)
        return Text(text)
            .font(Theme.monthLabelFont)
            .foregroundStyle(.tertiary)
            .fixedSize()
            .offset(x: xOffset)
    }

    private func color(for day: ReadingDay) -> Color {
        guard day.date != .distantPast else { return .clear }
        // Four intensity buckets. The 1–15 minute bucket was originally
        // 0.35 opacity, which read as "almost grey" on the vibrancy
        // background — but a day with 1+ min counts toward the streak,
        // so the cell should look visibly blue. Bumped to 0.55.
        let m = day.minutes
        switch m {
        case 0:        return Color.gray.opacity(0.12)
        case 1...15:   return Self.brand.opacity(0.55)
        case 16...45:  return Self.brand.opacity(0.80)
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
