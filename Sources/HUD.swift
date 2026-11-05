import Cocoa

/// 屏幕底部居中的悬浮提示，不会抢走键盘焦点。
final class HUD {
    private let panel: NSPanel
    private let card = NSView()
    private let tintView = NSView()
    private let iconBadge = NSView()
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let bodyLabel = NSTextField(wrappingLabelWithString: "")
    private var hideWork: DispatchWorkItem?

    private let panelWidth: CGFloat = 500
    private let panelHeight: CGFloat = 96
    private var opacity: CGFloat = 0.45

    private let accentListening = NSColor(calibratedRed: 0.32, green: 0.64, blue: 1.00, alpha: 1)
    private let accentProcessing = NSColor(calibratedRed: 0.36, green: 0.86, blue: 0.82, alpha: 1)
    private let accentSuccess = NSColor(calibratedRed: 0.36, green: 0.86, blue: 0.56, alpha: 1)
    private let accentError = NSColor(calibratedRed: 1.00, green: 0.63, blue: 0.30, alpha: 1)

    init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = false
        panel.ignoresMouseEvents = true
        panel.isReleasedWhenClosed = false
        panel.appearance = NSAppearance(named: .darkAqua)

        // 深色半透明卡片：只保留蒙层，让后面的内容能隐约透出来。
        card.frame = NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight)
        card.autoresizingMask = [.width, .height]
        card.wantsLayer = true
        card.layer?.cornerRadius = 22
        card.layer?.cornerCurve = .continuous
        card.layer?.masksToBounds = true
        panel.contentView = card

        tintView.frame = card.bounds
        tintView.autoresizingMask = [.width, .height]
        tintView.wantsLayer = true
        card.addSubview(tintView)
        applyBackground()

        iconBadge.translatesAutoresizingMaskIntoConstraints = false
        iconBadge.wantsLayer = true
        iconBadge.layer?.cornerRadius = 13
        iconBadge.layer?.cornerCurve = .continuous
        iconBadge.layer?.backgroundColor = accentListening.withAlphaComponent(0.18).cgColor

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: nil)
        iconView.contentTintColor = accentListening
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 23, weight: .semibold)
        iconBadge.addSubview(iconView)

        let textShadow = NSShadow()
        textShadow.shadowColor = NSColor.black.withAlphaComponent(0.75)
        textShadow.shadowBlurRadius = 4
        textShadow.shadowOffset = NSSize(width: 0, height: -1)

        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = NSColor.white.withAlphaComponent(0.98)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.maximumNumberOfLines = 1
        titleLabel.shadow = textShadow

        bodyLabel.font = .systemFont(ofSize: 13, weight: .regular)
        bodyLabel.textColor = NSColor.white.withAlphaComponent(0.86)
        bodyLabel.maximumNumberOfLines = 2
        bodyLabel.lineBreakMode = .byTruncatingTail
        bodyLabel.preferredMaxLayoutWidth = panelWidth - 40 - 42 - 14
        bodyLabel.shadow = textShadow

        let textStack = NSStackView(views: [titleLabel, bodyLabel])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 5

        let stack = NSStackView(views: [iconBadge, textStack])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        NSLayoutConstraint.activate([
            iconBadge.widthAnchor.constraint(equalToConstant: 42),
            iconBadge.heightAnchor.constraint(equalToConstant: 42),
            iconView.centerXAnchor.constraint(equalTo: iconBadge.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconBadge.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),

            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(greaterThanOrEqualTo: card.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: card.bottomAnchor, constant: -14),
            stack.centerYAnchor.constraint(equalTo: card.centerYAnchor)
        ])
    }

    /// 0.30 ~ 1.0，越小越透明。可在配置文件里改 hudOpacity，重载配置即可生效。
    func setOpacity(_ value: Double) {
        opacity = CGFloat(min(max(value, 0.30), 1.0))
        applyBackground()
    }

    private func applyBackground() {
        tintView.layer?.backgroundColor = NSColor(calibratedWhite: 0.012, alpha: opacity).cgColor
    }

    func showListening() {
        show(
            icon: "waveform",
            title: "正在聆听…",
            body: "松开右 Option 结束",
            accent: accentListening,
            autoHide: nil
        )
    }

    func updatePartial(_ text: String) {
        guard !text.isEmpty else { return }
        bodyLabel.stringValue = text
        titleLabel.stringValue = "正在聆听…"
    }

    func showProcessing() {
        show(
            icon: "ellipsis.circle",
            title: "识别中…",
            body: bodyLabel.stringValue,
            accent: accentProcessing,
            autoHide: nil
        )
    }

    func showInjected(_ text: String) {
        show(
            icon: "checkmark.circle.fill",
            title: "已输入",
            body: text,
            accent: accentSuccess,
            autoHide: 0.9
        )
    }

    func showError(_ message: String) {
        show(
            icon: "exclamationmark.triangle.fill",
            title: "出错了",
            body: message,
            accent: accentError,
            autoHide: 2.4
        )
    }

    func showInfo(title: String, body: String, autoHide: TimeInterval) {
        show(icon: "mic.fill", title: title, body: body, accent: accentListening, autoHide: autoHide)
    }

    func hide(after delay: TimeInterval) {
        hideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.fadeOut()
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func show(icon: String, title: String, body: String, accent: NSColor, autoHide: TimeInterval?) {
        hideWork?.cancel()

        iconView.image = NSImage(systemSymbolName: icon, accessibilityDescription: nil)
        iconView.contentTintColor = accent
        iconBadge.layer?.backgroundColor = accent.withAlphaComponent(0.18).cgColor
        titleLabel.stringValue = title
        bodyLabel.stringValue = body

        position()

        if !panel.isVisible {
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.12
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().alphaValue = 1
            }
        } else {
            panel.alphaValue = 1
            panel.orderFrontRegardless()
        }

        if let autoHide {
            hide(after: autoHide)
        }
    }

    private func fadeOut() {
        guard panel.isVisible else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.panel.orderOut(nil)
        })
    }

    private func position() {
        guard let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame
        let x = frame.midX - panelWidth / 2
        let y = frame.minY + 78
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
