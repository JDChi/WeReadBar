import SwiftUI

/// One-line summary under the stat tiles. Shows weekly total; falls back to
/// the "currently reading" book title if weekly total is zero.
struct SummaryLine: View {
    @ObservedObject var store: StatsStore

    var body: some View {
        Group {
            if store.weekTotalSeconds > 0 {
                Text("This week: \(formatHM(store.weekTotalSeconds))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let book = store.currentlyReading {
                HStack(spacing: 4) {
                    Image(systemName: "book")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(book.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            } else {
                Text(" ")
                    .font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func formatHM(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}
