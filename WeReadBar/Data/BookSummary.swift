import Foundation

/// Lightweight "currently reading" projection used by the popover.
struct BookSummary: Identifiable, Hashable {
    let bookId: String
    let title: String
    let author: String?
    let cover: String?
    let progressPercent: Double?

    var id: String { bookId }
}
