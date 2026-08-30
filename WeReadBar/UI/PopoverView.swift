import SwiftUI
import os

/// Root view of the popover. Owns the poll timer; opens the onboarding
/// window (a separate NSWindow) when the API key is missing.
struct PopoverView: View {
    @EnvironmentObject var store: StatsStore

    private let diagLog = Logger(subsystem: "com.local.wereadbar", category: "popover-diag")

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
                .frame(height: HeatmapLayout.totalHeight)

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
            // Diagnostic runs both BEFORE and AFTER refresh so we can
            // see whether data is loaded correctly when the heatmap renders.
            logLast14Days(label: "BEFORE_REFRESH")
            Task {
                await store.refresh()
                logLast14Days(label: "AFTER_REFRESH")
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

    /// Dump the last 14 days of `store.days` for diagnostics. Called
    /// both before and after `refresh()` so we can see what data the
    /// heatmap is actually rendering.
    private func logLast14Days(label: String) {
        let cal = Calendar(identifier: .gregorian)
        var c = cal
        c.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let today = c.startOfDay(for: Date())
        diagLog.notice("diag[\(label, privacy: .public)]: days.count=\(store.days.count, privacy: .public) streak=\(store.streak, privacy: .public) todaySec=\(store.todaySeconds, privacy: .public)")
        for offset in (0..<14).reversed() {
            if let d = c.date(byAdding: .day, value: -offset, to: today),
               let day = store.days.first(where: { c.isDate($0.date, inSameDayAs: d) }) {
                let weekday = c.component(.weekday, from: d)
                let weekdayName = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"][weekday-1]
                diagLog.notice("diag[\(label, privacy: .public)]: \(d, privacy: .public) \(weekdayName, privacy: .public) seconds=\(day.seconds, privacy: .public)")
            }
        }
    }
}
