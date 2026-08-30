import SwiftUI

/// Root view of the popover. Owns the poll timer; opens the onboarding
/// window (a separate NSWindow) when the API key is missing.
struct PopoverView: View {
    @EnvironmentObject var store: StatsStore

    /// 30-minute polling while popover is visible.
    private let timer = Timer.publish(every: 1800, on: .main, in: .common).autoconnect()
    @State private var pollTimerOn = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let err = store.lastError {
                ErrorBanner(message: err)
            }

            HeatmapView(days: store.days)
                .frame(height: 58)
                .overlay {
                    if store.isLoading && store.days.isEmpty {
                        ProgressView().controlSize(.small)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if store.isLoading && !store.days.isEmpty {
                        ProgressView().controlSize(.small).scaleEffect(0.6)
                    }
                }

            HStack(spacing: 8) {
                StatTile(
                    title: "Today",
                    value: formatMinutes(store.todaySeconds)
                )
                StatTile(
                    title: "Streak",
                    value: "\(store.streak) d"
                )
                StatTile(
                    title: "Shelf",
                    value: "\(store.shelfCount)"
                )
            }

            SummaryLine(store: store)

            HStack {
                Button {
                    Task { await store.refresh() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .font(.caption)
                }
                .controlSize(.small)
                .disabled(store.isLoading)

                Spacer()

                Text(store.isLoading ? "Loading…" : " ")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .frame(width: 380)
        .background(.regularMaterial)
        .onReceive(timer) { _ in
            if pollTimerOn { Task { await store.refresh() } }
        }
        .onAppear {
            pollTimerOn = true
            Task {
                await store.refresh()
                // Open the onboarding window if no token is stored.
                if store.needsAPIKey {
                    OnboardingWindowController.shared.show(store: store)
                }
            }
        }
        .onDisappear { pollTimerOn = false }
        // If needsAPIKey flips true later (e.g., right-click → Change API key),
        // pop the onboarding window open as well.
        .onChange(of: store.needsAPIKey) { _, needs in
            if needs { OnboardingWindowController.shared.show(store: store) }
        }
    }

    private func formatMinutes(_ seconds: Int) -> String {
        let m = seconds / 60
        if m == 0 { return "0m" }
        return "\(m)m"
    }
}
