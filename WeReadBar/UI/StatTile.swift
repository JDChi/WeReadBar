import SwiftUI

/// Reusable title + value card. Both font sizes come from `Theme`.
struct StatTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(Theme.statTileTitleFont)
                .foregroundStyle(.secondary)
            Text(value)
                .font(Theme.statTileValueFont)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            Color.gray.opacity(0.10),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
    }
}
