import SwiftUI

/// Compact red row shown above the heatmap when `lastError != nil`.
struct ErrorBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)
            Text(message)
                .font(Theme.errorBannerFont)
                .lineLimit(2)
                .truncationMode(.tail)
        }
        .foregroundStyle(.red)
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.red.opacity(0.10),
            in: RoundedRectangle(cornerRadius: 8)
        )
    }
}
