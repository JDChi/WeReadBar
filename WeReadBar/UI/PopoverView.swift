import SwiftUI

/// Root view of the popover. Owns the poll timer; opens the onboarding
/// window (a separate NSWindow) when the API key is missing.
struct PopoverView: View {
    @EnvironmentObject var store: StatsStore

    /// 30-minute polling while popover is visible.
    private let timer = Timer.publish(every: 1800, on: .main, in: .common).autoconnect()
    @State private var pollTimerOn = false

    /// Icon-slot spinner shows when we're either actively refreshing OR
    /// haven't successfully loaded data yet (first launch, cleared key,
    /// or a failed refresh leaving days empty). Keeps the Refresh button
    /// visually consistent with the skeleton heatmap state.
    private var buttonShowsSpinner: Bool {
        store.isLoading || !store.hasData
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let err = store.lastError {
                ErrorBanner(message: err)
            }

            HeatmapView(days: store.days)
                .frame(height: 90)

            HStack(spacing: 8) {
                StatTile(
                    title: String(localized: "tile.today"),
                    value: formatMinutes(store.todaySeconds)
                )
                StatTile(
                    title: String(localized: "tile.streak"),
                    value: String.localizedStringWithFormat(
                        NSLocalizedString("format.streakDays", comment: ""),
                        store.streak
                    )
                )
                StatTile(
                    title: String(localized: "tile.shelf"),
                    value: "\(store.shelfCount)"
                )
            }

            SummaryLine(store: store)

            HStack {
                // Spinner shows whenever we don't yet have data to display —
                // covers both "refresh in flight" (isLoading=true) and
                // "no usable data yet" (hasData=false, e.g. first launch
                // before bootstrap or after the user clears the API key).
                Button {
                    Task { await store.refresh() }
                } label: {
                    HStack(spacing: 4) {
                        // Reserve a fixed-width icon slot so the layout doesn't
                        // jiggle when the arrow swaps for a spinner. Both views
                        // occupy the same ZStack position; only opacity changes.
                        ZStack {
                            Image(systemName: "arrow.clockwise")
                                .opacity(buttonShowsSpinner ? 0 : 1)
                            ProgressView()
                                .controlSize(.small)
                                .scaleEffect(0.7)
                                .opacity(buttonShowsSpinner ? 1 : 0)
                        }
                        .frame(width: 13, height: 13)
                        Text(String(localized: "popover.refresh"))
                    }
                    .font(.caption)
                }
                .controlSize(.small)
                // Only disable while a refresh is actually in flight; if data
                // is just missing (no key, last refresh failed) keep it
                // clickable so the user can retry manually.
                .disabled(store.isLoading)

                Spacer()

                // "Go to Reading" opens WeRead's homepage in the user's
                // default browser (or the WeRead app if installed).
                Button {
                    NSWorkspace.shared.open(WeReadURL.homepage)
                } label: {
                    Label(String(localized: "goToRead"), systemImage: "book")
                        .font(.caption)
                }
                .controlSize(.small)
            }
        }
        .padding(12)
        .frame(width: 600)
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
        if m == 0 {
            return String(localized: "format.minutesZero")
        }
        return String.localizedStringWithFormat(
            NSLocalizedString("format.minutes", comment: ""),
            m
        )
    }
}
