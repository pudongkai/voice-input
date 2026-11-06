import Carbon

/// 用 Carbon 注册系统级快捷键。
/// 与 NSEvent 全局监听不同，注册后按键会被拦下，前台应用不会再收到同一个快捷键。
final class GlobalShortcut {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let action: () -> Void

    /// keyCode 用 Carbon 的虚拟键码（如 kVK_ANSI_V），modifiers 用 cmdKey、shiftKey 等组合。
    init?(keyCode: Int, modifiers: Int, action: @escaping () -> Void) {
        self.action = action

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        let installStatus = InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return noErr }
            let shortcut = Unmanaged<GlobalShortcut>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async { shortcut.action() }
            return noErr
        }, 1, &eventType, context, &handlerRef)

        let hotKeyID = EventHotKeyID(signature: OSType(0x5649_4E50), id: 1) // "VINP"
        let registerStatus = RegisterEventHotKey(
            UInt32(keyCode), UInt32(modifiers), hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef
        )
        guard installStatus == noErr, registerStatus == noErr else {
            Log.write("global shortcut register failed install=\(installStatus) register=\(registerStatus)")
            return nil
        }
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }
}
