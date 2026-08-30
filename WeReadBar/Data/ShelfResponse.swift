import Foundation

/// Decoded response from `POST /shelf/sync`.
/// Field names match the keys returned by the WeRead gateway.
struct ShelfResponse: Decodable {
    let errcode: Int?
    let errmsg: String?
    let books: [ShelfBook]?
    let albums: [ShelfAlbum]?
    let mp: ShelfMp?

    /// Total shelf count, per weread-skills docs:
    /// `books.length + albums.length + (mp ? 1 : 0)`.
    var totalCount: Int {
        (books?.count ?? 0) + (albums?.count ?? 0) + (mp == nil ? 0 : 1)
    }

    /// The most recently read book, or nil if shelf is empty.
    var firstReading: BookSummary? {
        guard let books, !books.isEmpty else { return nil }
        let top = books.max { ($0.readUpdateTime ?? 0) < ($1.readUpdateTime ?? 0) }
        guard let top else { return nil }
        let p = top.readProgress.map { Double($0) }
        let pct: Double? = {
            guard let p else { return nil }
            // readProgress is 0..10000 in some clients, but WeRead gateway uses 0..100.
            return p > 100 ? p / 100.0 : p
        }()
        return BookSummary(
            bookId: top.bookId ?? "",
            title: top.title ?? "(untitled)",
            author: top.author,
            cover: top.cover,
            progressPercent: pct
        )
    }

    /// True iff the server accepted the token.
    var isOK: Bool { errcode == nil || errcode == 0 }
}

struct ShelfBook: Decodable {
    let bookId: String?
    let title: String?
    let author: String?
    let cover: String?
    let readUpdateTime: Int?
    let readProgress: Int?
}

struct ShelfAlbum: Decodable {
    let albumId: String?
    let title: String?
}

/// `mp` (公众号 = WeChat official accounts) is sometimes null, sometimes an empty object.
struct ShelfMp: Decodable {
    let count: Int?
}
