import AppKit
import SwiftUI

/// One-line summary under the stat tiles. Always shows the weekly total and,
/// when available, the most recently read book with its progress.
struct SummaryLine: View {
    @ObservedObject var store: StatsStore
    @State private var isHoveringCurrentBook = false

    var body: some View {
        HStack(spacing: 12) {
            Text(String.localizedStringWithFormat(
                NSLocalizedString("summary.thisWeek", comment: ""),
                formatHM(store.weekTotalSeconds)
            ))
            .font(Theme.summaryLineFont)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: true, vertical: false)

            Spacer(minLength: 8)

            if let book = store.currentlyReading {
                currentBook(book)
                    .frame(maxWidth: 360, alignment: .trailing)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func currentBook(_ book: BookSummary) -> some View {
        let label = currentBookLabel(book)

        if let readingURL = book.readingURL {
            Button {
                NSWorkspace.shared.open(readingURL)
            } label: {
                label
            }
            .buttonStyle(.plain)
            .help(String(localized: "summary.continueReading"))
            .onHover { isHoveringCurrentBook = $0 }
        } else {
            label
        }
    }

    private func currentBookLabel(_ book: BookSummary) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "book")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Text(book.title)
                .lineLimit(1)
                .truncationMode(.tail)

            if let progress = book.progressPercent {
                Text(verbatim: formatProgress(progress))
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
        .font(Theme.summaryLineFont)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(
            isHoveringCurrentBook ? Color.accentColor.opacity(0.12) : .clear,
            in: RoundedRectangle(cornerRadius: 4, style: .continuous)
        )
        .contentShape(Rectangle())
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

    private func formatProgress(_ progress: Double) -> String {
        String(Int(max(0, min(100, progress.rounded())))) + "%"
    }
}
