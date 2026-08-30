import SwiftUI

/// Compact red row shown above the heatmap when `lastError != nil`.
struct ErrorBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption2)
            Text(message)
                .font(.caption)
                .lineLimit(2)
                .truncationMode(.tail)
        }
        .foregroundStyle(.red)
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.red.opacity(0.10),
            in: RoundedRectangle(cornerRadius: 6)
        )
    }
}
