import Foundation

public protocol RunHistoryStore: Sendable {
    func load(limit: Int) -> [RunHistoryEntry]
    func append(_ entry: RunHistoryEntry)
    func clear()
}

public struct NoopRunHistoryStore: RunHistoryStore {
    public init() {}

    public func load(limit: Int) -> [RunHistoryEntry] {
        []
    }

    public func append(_ entry: RunHistoryEntry) {}

    public func clear() {}
}
