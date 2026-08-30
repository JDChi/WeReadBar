import SwiftUI

/// Centralized typography + key UI metrics. Single source of truth so font
/// sizes / popover dimensions / corner radii are tweaked in one place.
///
/// Layout vs typography is split: heatmap geometry (cell size, spacing,
/// column count) lives in `HeatmapLayout` because those values have
/// hard mathematical relationships. Fonts and the popover's outer
/// dimensions live here because they're presentation-only.
enum Theme {

    // MARK: - Layout

    /// Width of the popover. Sized to fit:
    ///   28pt gutter + 53 cells × 12pt + 52 × 1pt gaps = 716pt of content,
    ///   plus 24pt padding × 2 = 764pt minimum. Rounded up to 780pt.
    static let popoverWidth: CGFloat = 780
    static let popoverPadding: CGFloat = 14
    static let popoverRowSpacing: CGFloat = 12
    static let tileRowSpacing: CGFloat = 10

    // MARK: - Typography

    /// Heatmap left-gutter weekday labels (Mon / Wed / Fri).
    static let weekdayLabelFont: Font = .system(size: 11, weight: .medium)

    /// Heatmap month labels above the grid (Sep, Oct, ...).
    static let monthLabelFont: Font = .system(size: 10, weight: .medium)

    /// StatTile title row (Today / Streak / Shelf).
    static let statTileTitleFont: Font = .subheadline

    /// StatTile value (the big number).
    static let statTileValueFont: Font = .title.weight(.semibold)

    /// Summary line under the stat tiles ("This week: …").
    static let summaryLineFont: Font = .footnote

    /// Inline error banner shown above the heatmap when a refresh fails.
    static let errorBannerFont: Font = .subheadline

    /// Footer buttons (Refresh, Go to Reading).
    static let footerButtonFont: Font = .body

    // MARK: - Onboarding window

    static let onboardingTitleFont: Font = .title2.weight(.semibold)
    static let onboardingBodyFont: Font = .body
    static let onboardingButtonFont: Font = .body
    static let onboardingLinkFont: Font = .caption
}
