import Foundation

public final class FileRunHistoryStore: RunHistoryStore, @unchecked Sendable {
    private let fileURL: URL
    private let maxStoredEntries: Int
    private let fileManager: FileManager
    private let lock = NSLock()
    private var entries: [RunHistoryEntry]

    public init(
        fileURL: URL? = nil,
        maxStoredEntries: Int = 50,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        self.maxStoredEntries = max(1, maxStoredEntries)
        self.fileURL = fileURL ?? Self.defaultHistoryFileURL(fileManager: fileManager)
        self.entries = []

        let persistedEntries = readEntriesFromDisk()
        let normalizedEntries = Self.normalize(
            entries: persistedEntries,
            maxStoredEntries: self.maxStoredEntries
        )
        self.entries = normalizedEntries

        if normalizedEntries != persistedEntries {
            persistLockedEntries()
        }
    }

    public func load(limit: Int) -> [RunHistoryEntry] {
        lock.withLock {
            guard limit > 0 else {
                return []
            }
            return Array(entries.prefix(limit))
        }
    }

    public func append(_ entry: RunHistoryEntry) {
        lock.withLock {
            entries.insert(entry, at: 0)
            entries = Self.normalize(entries: entries, maxStoredEntries: maxStoredEntries)
            persistLockedEntries()
        }
    }

    public func clear() {
        lock.withLock {
            entries = []
            persistLockedEntries()
        }
    }

    private func readEntriesFromDisk() -> [RunHistoryEntry] {
        lock.withLock {
            guard fileManager.fileExists(atPath: fileURL.path) else {
                return []
            }

            do {
                let data = try Data(contentsOf: fileURL)
                let decoded = try JSONDecoder().decode([RunHistoryEntry].self, from: data)
                return decoded.sorted { $0.createdAt > $1.createdAt }
            } catch {
                return []
            }
        }
    }

    private static func normalize(
        entries: [RunHistoryEntry],
        maxStoredEntries: Int
    ) -> [RunHistoryEntry] {
        let sortedEntries = entries.sorted { $0.createdAt > $1.createdAt }
        if sortedEntries.count > maxStoredEntries {
            return Array(sortedEntries.prefix(maxStoredEntries))
        }
        return sortedEntries
    }

    private func persistLockedEntries() {
        do {
            let directory = fileURL.deletingLastPathComponent()
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(entries)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            // Keep app behavior resilient if persistence fails.
        }
    }

    private static func defaultHistoryFileURL(fileManager: FileManager) -> URL {
        do {
            let appSupport = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            return appSupport
                .appendingPathComponent("Morpho", isDirectory: true)
                .appendingPathComponent("run-history.json")
        } catch {
            return fileManager.temporaryDirectory
                .appendingPathComponent("Morpho", isDirectory: true)
                .appendingPathComponent("run-history.json")
        }
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
