import AppKit
import Foundation

struct PasteboardItemSnapshot {
    let payloads: [NSPasteboard.PasteboardType: Data]
}

struct PasteboardSnapshot {
    let items: [PasteboardItemSnapshot]
    let changeCount: Int
}

protocol PasteboardAccessing {
    var changeCount: Int { get }
    func snapshot() -> PasteboardSnapshot
    func restore(_ snapshot: PasteboardSnapshot)
    func readString() -> String?
    func writeString(_ value: String)
}

final class SystemPasteboardAccessor: PasteboardAccessing {
    private let pasteboard: NSPasteboard

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    var changeCount: Int {
        pasteboard.changeCount
    }

    func snapshot() -> PasteboardSnapshot {
        let items: [PasteboardItemSnapshot] = pasteboard.pasteboardItems?.map { item in
            var payloads: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    payloads[type] = data
                }
            }
            return PasteboardItemSnapshot(payloads: payloads)
        } ?? []

        return PasteboardSnapshot(items: items, changeCount: pasteboard.changeCount)
    }

    func restore(_ snapshot: PasteboardSnapshot) {
        pasteboard.clearContents()
        guard !snapshot.items.isEmpty else {
            return
        }

        let restoredItems = snapshot.items.map { snapshot in
            let item = NSPasteboardItem()
            for (type, data) in snapshot.payloads {
                item.setData(data, forType: type)
            }
            return item
        }

        _ = pasteboard.writeObjects(restoredItems)
    }

    func readString() -> String? {
        if let string = pasteboard.string(forType: .string) {
            return string
        }

        let objects = pasteboard.readObjects(forClasses: [NSString.self], options: nil)
        return objects?.first as? String
    }

    func writeString(_ value: String) {
        pasteboard.clearContents()
        pasteboard.setString(value, forType: .string)
    }
}
