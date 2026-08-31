import Foundation

/// Decoded response from the book progress endpoint.
struct BookProgressResponse: Decodable {
    let errcode: Int?
    let errmsg: String?
    let book: BookProgress?

    var isOK: Bool { errcode == nil || errcode == 0 }
}

struct BookProgress: Decodable {
    /// Integer percentage in the inclusive range 0...100.
    let progress: Int?
}
