import Foundation

/// Lightweight "currently reading" projection used by the popover.
struct BookSummary: Identifiable, Hashable {
    let bookId: String
    let title: String
    let author: String?
    let cover: String?
    let progressPercent: Double?
    /// Official WeRead jump target supplied by `/shelf/sync`.
    let deepLink: URL?

    var id: String { bookId }

    func replacingProgress(with progress: Int) -> BookSummary {
        BookSummary(
            bookId: bookId,
            title: title,
            author: author,
            cover: cover,
            progressPercent: Double(progress),
            deepLink: deepLink
        )
    }

    /// Prefers the web reader when the official detail link supplies its encoded
    /// reader identifier (`v`); otherwise preserves the official link unchanged.
    var readingURL: URL? {
        guard let deepLink else { return nil }
        guard deepLink.scheme == "https", deepLink.host == "weread.qq.com" else {
            return deepLink
        }

        if deepLink.path.hasPrefix("/web/reader/") {
            return deepLink
        }

        guard let components = URLComponents(url: deepLink, resolvingAgainstBaseURL: false),
              let readerID = components.queryItems?.first(where: { $0.name == "v" })?.value,
              !readerID.isEmpty,
              readerID.unicodeScalars.allSatisfy(CharacterSet.alphanumerics.contains),
              let webReaderURL = URL(string: "https://weread.qq.com/web/reader/\(readerID)") else {
            return deepLink
        }
        return webReaderURL
    }
}
