import AppKit
import Foundation

/// Everything needed to put the clipboard back exactly as it was
/// after a clean paste (spec §22).
struct PasteboardRestorePoint {
    let changeCount: Int
    let items: [[(type: NSPasteboard.PasteboardType, data: Data)]]
}

/// Writes the cleaned text to the clipboard and restores the original
/// afterwards. Every call happens on demand — nothing is observed or
/// polled (spec §24).
struct ClipboardWriter {
    private let pasteboard: NSPasteboard

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    /// Captures the full current state for later restoration.
    func captureRestorePoint() -> PasteboardRestorePoint {
        let changeCount = pasteboard.changeCount
        var items: [[(type: NSPasteboard.PasteboardType, data: Data)]] = []

        for item in pasteboard.pasteboardItems ?? [] {
            var flavors: [(type: NSPasteboard.PasteboardType, data: Data)] = []
            for type in item.types {
                if let data = item.data(forType: type) {
                    flavors.append((type, data))
                }
            }
            items.append(flavors)
        }

        return PasteboardRestorePoint(changeCount: changeCount, items: items)
    }

    /// Replaces the clipboard with the cleaned plain text.
    /// Returns the pasteboard's changeCount after the write (used later to
    /// verify nobody else wrote in the meantime), or nil on failure.
    @discardableResult
    func writeForPaste(_ text: String) -> Int? {
        pasteboard.clearContents()
        let item = NSPasteboardItem()
        item.setString(text, forType: .string)
        guard pasteboard.writeObjects([item]) else { return nil }
        return pasteboard.changeCount
    }

    /// Restores a captured state, but only if the clipboard still holds
    /// exactly what we wrote — a newer copy made in the meantime is never
    /// clobbered. Returns whether the restoration happened.
    @discardableResult
    func restore(_ point: PasteboardRestorePoint, expectingChangeCount expected: Int) -> Bool {
        guard pasteboard.changeCount == expected else { return false }

        pasteboard.clearContents()
        guard !point.items.isEmpty else { return true }

        let items: [NSPasteboardItem] = point.items.map { flavors in
            let item = NSPasteboardItem()
            for flavor in flavors {
                item.setData(flavor.data, forType: flavor.type)
            }
            return item
        }
        return pasteboard.writeObjects(items)
    }
}
