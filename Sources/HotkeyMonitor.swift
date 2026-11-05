import Cocoa

/// 监听全局按键：按住右 Option 开始，松开结束；按住期间按其它键视为快捷键，取消录音。
final class HotkeyMonitor {
    var onPress: (() -> Void)?
    var onRelease: ((TimeInterval) -> Void)?
    var onCancel: (() -> Void)?

    private var monitor: Any?
    private var pressedAt: Date?
    private let rightOptionKeyCode: UInt16 = 61

    func start() {
        stop()
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] event in
            self?.handle(event)
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        pressedAt = nil
    }

    private func handle(_ event: NSEvent) {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in self?.handle(event) }
            return
        }

        switch event.type {
        case .flagsChanged:
            guard event.keyCode == rightOptionKeyCode else { return }
            let optionDown = event.modifierFlags.contains(.option)
            if optionDown, pressedAt == nil {
                pressedAt = Date()
                onPress?()
            } else if !optionDown, pressedAt != nil {
                let duration = Date().timeIntervalSince(pressedAt!)
                pressedAt = nil
                onRelease?(duration)
            }

        case .keyDown:
            guard pressedAt != nil else { return }
            if event.keyCode == 53 { // Esc
                pressedAt = nil
                onCancel?()
            } else {
                // 右 Option 被当作组合键使用（如 Option+方向键），取消本次录音。
                pressedAt = nil
                onCancel?()
            }

        default:
            break
        }
    }
}
