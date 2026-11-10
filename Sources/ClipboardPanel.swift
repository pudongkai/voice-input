import Cocoa
import SwiftUI

/// 面板的键盘处理和 SwiftUI 视图共用的状态。
final class ClipboardPickerModel: ObservableObject {
    @Published var selection = 0
    /// 与录音悬浮窗共用「悬浮窗透明度」设置。
    @Published var opacity = 0.45
    /// 每次打开面板时更新，列表据此滚回最顶部。
    @Published var presentedAt = Date()
}

/// 剪贴板历史选择面板。
/// 使用不激活应用的浮动面板：前台应用保持焦点，选中后可以直接粘贴回去。
final class ClipboardPanel: NSPanel {
    var onPick: ((ClipboardEntry) -> Void)?

    private let history: ClipboardHistory
    private let model = ClipboardPickerModel()
    private static let width: CGFloat = 400
    private static let rowHeight: CGFloat = 52
    private static let maxVisibleRows = 8
    /// 用户拖动过面板后记住左上角位置，之后都在这里打开，直到 App 退出。
    private var userTopLeft: NSPoint?

    init(history: ClipboardHistory) {
        self.history = history
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: Self.width, height: 300),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        isFloatingPanel = true
        level = .popUpMenu
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        appearance = NSAppearance(named: .darkAqua)

        let list = ClipboardListView(history: history, model: model) { [weak self] entry in
            self?.pick(entry)
        }
        contentView = NSHostingView(rootView: list)
    }

    override var canBecomeKey: Bool { true }

    func setOpacity(_ value: Double) {
        model.opacity = min(max(value, 0.30), 1.0)
    }

    /// 默认在鼠标附近弹出；拖动过就在上次的位置打开。超出屏幕时往里收。
    func present() {
        model.selection = 0
        model.presentedAt = Date()
        let rows = min(max(history.entries.count, 1), Self.maxVisibleRows)
        let size = NSSize(width: Self.width, height: CGFloat(rows) * Self.rowHeight + 88)
        let target: NSRect
        if let topLeft = userTopLeft {
            target = Self.clamped(NSRect(x: topLeft.x, y: topLeft.y - size.height, width: size.width, height: size.height))
        } else {
            target = Self.frame(near: NSEvent.mouseLocation, size: size)
        }
        setFrame(target, display: true)
        makeKeyAndOrderFront(nil)
    }

    fileprivate func didFinishDragging() {
        userTopLeft = NSPoint(x: frame.minX, y: frame.maxY)
    }

    override func resignKey() {
        super.resignKey()
        close()
    }

    override func keyDown(with event: NSEvent) {
        let count = history.entries.count
        switch event.keyCode {
        case 53: // Esc
            close()
        case 125: // ↓
            if count > 0 { model.selection = (model.selection + 1) % count }
        case 126: // ↑
            if count > 0 { model.selection = (model.selection - 1 + count) % count }
        case 36, 76: // Return / Enter
            pickSelected()
        default:
            pickByDigit(event.charactersIgnoringModifiers)
        }
    }

    private func pickByDigit(_ characters: String?) {
        guard let characters, let digit = Int(characters), (1...9).contains(digit) else { return }
        guard digit <= history.entries.count else { return }
        model.selection = digit - 1
        pickSelected()
    }

    private func pickSelected() {
        guard history.entries.indices.contains(model.selection) else { return }
        pick(history.entries[model.selection])
    }

    private func pick(_ entry: ClipboardEntry) {
        close()
        onPick?(entry)
    }

    private static func frame(near point: NSPoint, size: NSSize) -> NSRect {
        clamped(NSRect(origin: NSPoint(x: point.x - 20, y: point.y - size.height - 12), size: size))
    }

    private static func clamped(_ rect: NSRect) -> NSRect {
        let center = NSPoint(x: rect.midX, y: rect.midY)
        let screen = NSScreen.screens.first { $0.frame.contains(center) } ?? NSScreen.main
        guard let bounds = screen?.visibleFrame else { return rect }
        var origin = rect.origin
        origin.x = min(max(origin.x, bounds.minX + 8), bounds.maxX - rect.width - 8)
        origin.y = min(max(origin.y, bounds.minY + 8), bounds.maxY - rect.height - 8)
        return NSRect(origin: origin, size: rect.size)
    }
}

// MARK: - SwiftUI

private struct ClipboardListView: View {
    @ObservedObject var history: ClipboardHistory
    @ObservedObject var model: ClipboardPickerModel
    let onPick: (ClipboardEntry) -> Void

    var body: some View {
        VStack(spacing: 0) {
            header.overlay(WindowDragArea())
            Divider().opacity(0.4)
            if history.entries.isEmpty {
                emptyState
            } else {
                list
            }
            Divider().opacity(0.4)
            footer.overlay(WindowDragArea())
        }
        // 与录音悬浮窗一致：半透明黑底，文字加阴影保证浅色背景上也能看清。
        .shadow(color: .black.opacity(0.75), radius: 1.5, x: 0, y: 1)
        .background(Color(white: 0.012).opacity(model.opacity))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.on.clipboard")
                .foregroundColor(Color(red: 0.32, green: 0.64, blue: 1.0))
            Text(L("剪贴板历史", "Clipboard History")).font(.system(size: 13, weight: .semibold))
            Spacer()
            Text(L("\(history.entries.count) 条", "\(history.entries.count) items")).font(.system(size: 11)).foregroundColor(.secondary)
        }
        .padding(.horizontal, 14)
        .frame(height: 40)
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(history.entries.enumerated()), id: \.element.id) { index, entry in
                        // 行的身份只能由 ForEach 按记录 id 决定；再加 .id(index) 会让新记录插到最前时沿用旧行的内容。
                        ClipboardRow(entry: entry, index: index, selected: index == model.selection)
                            .contentShape(Rectangle())
                            .onTapGesture { onPick(entry) }
                            .onHover { inside in if inside { model.selection = index } }
                    }
                }
                .padding(6)
            }
            .onChange(of: model.selection) { index in
                guard history.entries.indices.contains(index) else { return }
                proxy.scrollTo(history.entries[index].id)
            }
            .onChange(of: model.presentedAt) { _ in
                if let first = history.entries.first {
                    proxy.scrollTo(first.id, anchor: .top)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "tray").font(.system(size: 22)).foregroundColor(.secondary)
            Text(L("还没有复制过内容", "Nothing copied yet")).font(.system(size: 12)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack(spacing: 14) {
            KeyHint(keys: "↑↓", label: L("选择", "Select"))
            KeyHint(keys: "↩", label: L("粘贴", "Paste"))
            KeyHint(keys: "1-9", label: L("快速粘贴", "Quick paste"))
            Spacer()
            KeyHint(keys: "esc", label: L("关闭", "Close"))
        }
        .padding(.horizontal, 14)
        .frame(height: 30)
    }
}

private struct ClipboardRow: View {
    let entry: ClipboardEntry
    let index: Int
    let selected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text(index < 9 ? "\(index + 1)" : "")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(selected ? .white : .secondary)
                .frame(width: 14)
            preview
            Spacer(minLength: 6)
            Text(Self.relativeTime(entry.copiedAt))
                .font(.system(size: 10))
                .foregroundColor(selected ? .white.opacity(0.8) : .secondary)
        }
        .padding(.horizontal, 10)
        .frame(height: 50)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(selected ? Color(red: 0.23, green: 0.48, blue: 0.96) : Color.clear)
        )
    }

    @ViewBuilder private var preview: some View {
        switch entry.content {
        case .text(let text):
            Text(Self.singleSpaced(text))
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.95))
                .lineLimit(2)
                .truncationMode(.tail)
        case .image(_, let thumbnail, let pixelSize):
            HStack(spacing: 10) {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 52, height: 38)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.white.opacity(0.15)))
                Text(verbatim: L("图片", "Image") + "  \(Int(pixelSize.width))×\(Int(pixelSize.height))")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.85))
            }
        }
    }

    /// 换行和连续空白压成一个空格，列表里尽量多显示内容。
    private static func singleSpaced(_ text: String) -> String {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).joined(separator: " ")
    }

    private static func relativeTime(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return L("刚刚", "just now") }
        if seconds < 3600 { return L("\(seconds / 60) 分钟前", "\(seconds / 60) min ago") }
        if seconds < 86400 { return L("\(seconds / 3600) 小时前", "\(seconds / 3600) h ago") }
        return L("\(seconds / 86400) 天前", "\(seconds / 86400) d ago")
    }
}

private struct KeyHint: View {
    let keys: String
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Text(keys)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.12)))
            Text(label).font(.system(size: 10))
        }
        .foregroundColor(.secondary)
    }
}

/// 盖在标题栏和底栏上的透明区域，按住即可拖动面板。
private struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { DragView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class DragView: NSView {
        override func resetCursorRects() {
            addCursorRect(bounds, cursor: .openHand)
        }

        override func mouseDown(with event: NSEvent) {
            guard let window else { return }
            // performDrag 会一直跟随鼠标，松开后才返回。
            window.performDrag(with: event)
            (window as? ClipboardPanel)?.didFinishDragging()
        }
    }
}
