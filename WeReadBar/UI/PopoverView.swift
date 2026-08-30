import SwiftUI

/// Root view of the popover. Owns the poll timer; opens the onboarding
/// window (a separate NSWindow) when the API key is missing.
struct PopoverView: View {
    @EnvironmentObject var store: StatsStore

    /// 30-minute polling while popover is visible.
    private let timer = Timer.publish(every: 1800, on: .main, in: .common).autoconnect()
    @State private var pollTimerOn = false

    /// Spinner shows when we're either actively refreshing OR
    /// haven't successfully loaded data yet (first launch, cleared key,
    /// or a failed refresh leaving days empty).
    private var buttonShowsSpinner: Bool {
        store.isLoading || !store.hasData
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.popoverRowSpacing) {
            if let err = store.lastError {
                ErrorBanner(message: err)
            }

            HeatmapView(days: store.days)
                .frame(height: 120)

            HStack(spacing: 10) {
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
                // "Go to Reading" opens WeRead's homepage in the user's
                // default browser (or the WeRead app if installed).
                Button {
                    NSWorkspace.shared.open(WeReadURL.homepage)
                } label: {
                    Label(String(localized: "goToRead"), systemImage: "book")
                        .font(Theme.footerButtonFont)
                }
                .controlSize(.regular)

                Spacer()

                // Refresh button. Spinner during load.
                Button {
                    Task { await store.refresh() }
                } label: {
                    HStack(spacing: 4) {
                        // Fixed-width icon slot to avoid layout jiggle.
                        ZStack {
                            Image(systemName: "arrow.clockwise")
                                .opacity(buttonShowsSpinner ? 0 : 1)
                            ProgressView()
                                .controlSize(.small)
                                .scaleEffect(0.7)
                                .opacity(buttonShowsSpinner ? 1 : 0)
                        }
                        .frame(width: 16, height: 16)
                        Text(String(localized: "popover.refresh"))
                    }
                    .font(Theme.footerButtonFont)
                }
                .controlSize(.regular)
                // Only disable while a refresh is actually in flight.
                .disabled(store.isLoading)
            }
        }
        .padding(Theme.popoverPadding)
        .frame(width: Theme.popoverWidth)
        .background(.regularMaterial)
        .onReceive(timer) { _ in
            if pollTimerOn { Task { await store.refresh() } }
        }
        .onAppear {
            pollTimerOn = true
            Task {
                await store.refresh()
                if store.needsAPIKey {
                    OnboardingWindowController.shared.show(store: store)
                }
            }
        }
        .onDisappear { pollTimerOn = false }
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
