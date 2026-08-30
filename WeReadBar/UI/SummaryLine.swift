import SwiftUI

/// One-line summary under the stat tiles. Shows weekly total; falls back
/// to the currently-reading book title when the week is empty.
struct SummaryLine: View {
    @ObservedObject var store: StatsStore

    var body: some View {
        Group {
            if store.weekTotalSeconds > 0 {
                Text(String.localizedStringWithFormat(
                    NSLocalizedString("summary.thisWeek", comment: ""),
                    formatHM(store.weekTotalSeconds)
                ))
                .font(Theme.summaryLineFont)
                .foregroundStyle(.secondary)
            } else if let book = store.currentlyReading {
                HStack(spacing: 4) {
                    Image(systemName: "book")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text(book.title)
                        .font(Theme.summaryLineFont)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            } else {
                Text(" ")
                    .font(Theme.summaryLineFont)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func formatHM(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        if h > 0 {
            return String.localizedStringWithFormat(
                NSLocalizedString("format.hoursMinutes", comment: ""),
                h, m
            )
        }
        return String.localizedStringWithFormat(
            NSLocalizedString("format.minutesShort", comment: ""),
            m
        )
    }
}
