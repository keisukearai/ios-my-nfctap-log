import Foundation

/// 履歴のページ計算。ビューから切り出してあるのは、
/// 削除でページ数が減ったときのクランプがバグを出しやすいため。
struct Pagination {
    static let pageSize = 10

    let total: Int
    let pageSize: Int
    private let requestedPage: Int

    init(total: Int, requestedPage: Int, pageSize: Int = Pagination.pageSize) {
        self.total = max(0, total)
        self.pageSize = max(1, pageSize)
        self.requestedPage = requestedPage
    }

    /// 0件でも1ページとして扱う（`1 / 1ページ` と表示するため）。
    var pageCount: Int {
        max(1, Int(ceil(Double(total) / Double(pageSize))))
    }

    /// 範囲外の要求は端に丸める。
    var page: Int {
        min(max(0, requestedPage), pageCount - 1)
    }

    var startIndex: Int { page * pageSize }

    var count: Int { max(0, min(pageSize, total - startIndex)) }

    var hasPrevious: Bool { page > 0 }
    var hasNext: Bool { page < pageCount - 1 }
}

enum TagOrdering {
    /// ホームの並び順。最後のタップが古い順で、未記録は最上位。
    /// 同着（未記録どうしなど）は登録が早いほうを上にして順序を安定させる。
    static func forHome(_ tags: [TagItem]) -> [TagItem] {
        tags.sorted { lhs, rhs in
            lhs.sortKey == rhs.sortKey ? lhs.createdAt < rhs.createdAt : lhs.sortKey < rhs.sortKey
        }
    }
}
