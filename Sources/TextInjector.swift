import Cocoa

enum TextInjector {
    /// 把文字输入到当前最前面的应用。
    static func insert(_ text: String, method: String, restoreClipboard: Bool) {
        switch method {
        case "type":
            typeUnicode(text)
        default:
            paste(text, restoreClipboard: restoreClipboard)
        }
    }

    private struct SavedItem {
        let values: [(NSPasteboard.PasteboardType, Data)]
    }

    private static func paste(_ text: String, restoreClipboard: Bool) {
        let pasteboard = NSPasteboard.general

        let saved = restoreClipboard ? snapshot(pasteboard) : []

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        let ownChangeCount = pasteboard.changeCount

        postCommandV()

        guard restoreClipboard, !saved.isEmpty else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            // 如果用户在这期间复制了新内容，就不要覆盖回去。
            if pasteboard.changeCount == ownChangeCount {
                restore(saved, to: pasteboard)
            }
        }
    }

    private static func snapshot(_ pasteboard: NSPasteboard) -> [SavedItem] {
        (pasteboard.pasteboardItems ?? []).map { item in
            SavedItem(values: item.types.compactMap { type in
                guard let data = item.data(forType: type) else { return nil }
                return (type, data)
            })
        }
    }

    private static func restore(_ items: [SavedItem], to pasteboard: NSPasteboard) {
        let objects: [NSPasteboardItem] = items.compactMap { saved in
            guard !saved.values.isEmpty else { return nil }
            let item = NSPasteboardItem()
            for (type, data) in saved.values {
                item.setData(data, forType: type)
            }
            return item
        }
        guard !objects.isEmpty else { return }
        pasteboard.clearContents()
        pasteboard.writeObjects(objects)
    }

    private static func postCommandV() {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyCodeV: CGKeyCode = 0x09

        let down = CGEvent(keyboardEventSource: source, virtualKey: keyCodeV, keyDown: true)
        down?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)

        Thread.sleep(forTimeInterval: 0.008)

        let up = CGEvent(keyboardEventSource: source, virtualKey: keyCodeV, keyDown: false)
        up?.flags = .maskCommand
        up?.post(tap: .cghidEventTap)
    }

    /// 直接发送 Unicode 键盘事件，不走剪贴板。部分终端对这种方式支持较差，作为备选。
    private static func typeUnicode(_ text: String) {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }
        let units = Array(text.utf16)
        var index = 0

        while index < units.count {
            let length = min(20, units.count - index)
            let chunk = Array(units[index..<(index + length)])

            if let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) {
                chunk.withUnsafeBufferPointer { buffer in
                    down.keyboardSetUnicodeString(stringLength: length, unicodeString: buffer.baseAddress)
                }
                down.post(tap: .cghidEventTap)
            }
            if let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) {
                chunk.withUnsafeBufferPointer { buffer in
                    up.keyboardSetUnicodeString(stringLength: length, unicodeString: buffer.baseAddress)
                }
                up.post(tap: .cghidEventTap)
            }

            index += length
            Thread.sleep(forTimeInterval: 0.004)
        }
    }
}
