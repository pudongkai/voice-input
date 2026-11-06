import AppKit

// 1024×1024 画布，底板按 macOS 图标规范占 824×824，四周留给投影。
let size: CGFloat = 1024
let plateRect = NSRect(x: 100, y: 100, width: 824, height: 824)

/// 接近 macOS 图标的连续圆角（超椭圆），比普通圆角矩形的四角过渡更平滑。
func squircle(in rect: NSRect, exponent n: CGFloat = 5) -> NSBezierPath {
    let path = NSBezierPath()
    let a = rect.width / 2, b = rect.height / 2
    for degree in 0...360 {
        let t = CGFloat(degree) * .pi / 180
        let c = cos(t), s = sin(t)
        let x = rect.midX + a * (c < 0 ? -1 : 1) * pow(abs(c), 2 / n)
        let y = rect.midY + b * (s < 0 ? -1 : 1) * pow(abs(s), 2 / n)
        degree == 0 ? path.move(to: NSPoint(x: x, y: y)) : path.line(to: NSPoint(x: x, y: y))
    }
    path.close()
    return path
}

func color(_ hex: Int, alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255,
            green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255,
            alpha: alpha)
}

func withShadow(_ shadowColor: NSColor, blur: CGFloat, offsetY: CGFloat, _ draw: () -> Void) {
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = shadowColor
    shadow.shadowBlurRadius = blur
    shadow.shadowOffset = NSSize(width: 0, height: offsetY)
    shadow.set()
    draw()
    NSGraphicsContext.restoreGraphicsState()
}

/// 蓝到薄荷绿的渐变底板，带投影、顶部柔光和细描边。
func drawPlate() {
    let plate = squircle(in: plateRect)
    withShadow(color(0x0b1e4a, alpha: 0.35), blur: 30, offsetY: -14) {
        color(0x3b6cf0).setFill()
        plate.fill()
    }
    NSGradient(colors: [color(0x3b6cf0), color(0x37c6b0)])!.draw(in: plate, angle: -45)

    // 顶部柔光沿底板形状从上往下淡出。
    NSGraphicsContext.saveGraphicsState()
    plate.addClip()
    let upperHalf = NSRect(x: plateRect.minX, y: plateRect.midY,
                           width: plateRect.width, height: plateRect.height / 2)
    NSGradient(colors: [NSColor.white.withAlphaComponent(0.22), NSColor.white.withAlphaComponent(0)])!
        .draw(in: upperHalf, angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    // 细描边让图标在深色背景上轮廓更清楚。
    NSColor.white.withAlphaComponent(0.18).setStroke()
    plate.lineWidth = 3
    plate.stroke()
}

/// 话筒和背后的框沿用最初版本的坐标（针对 880 宽的底板设计），整体按新底板比例缩放，造型不变。
func inOriginalLayout(_ draw: () -> Void) {
    let transform = NSAffineTransform()
    transform.translateX(by: size / 2, yBy: size / 2)
    transform.scale(by: plateRect.width / 880)
    transform.translateX(by: -size / 2, yBy: -size / 2)
    NSGraphicsContext.saveGraphicsState()
    transform.concat()
    draw()
    NSGraphicsContext.restoreGraphicsState()
}

/// 话筒背后的半透明圆角框：从上往下渐淡，加一圈细白边。
func drawBackdropFrame() {
    inOriginalLayout {
        let frame = NSBezierPath(roundedRect: NSRect(x: 150, y: 540, width: 724, height: 290), xRadius: 145, yRadius: 145)
        NSGradient(colors: [NSColor.white.withAlphaComponent(0.20), NSColor.white.withAlphaComponent(0.06)])!
            .draw(in: frame, angle: -90)
        NSColor.white.withAlphaComponent(0.22).setStroke()
        frame.lineWidth = 3
        frame.stroke()
    }
}

/// 白色话筒。
func drawMicrophone() {
    inOriginalLayout {
        withShadow(color(0x0a3060, alpha: 0.3), blur: 16, offsetY: -6) {
            NSColor.white.setFill()
            NSColor.white.setStroke()

            NSBezierPath(roundedRect: NSRect(x: 422, y: 408, width: 180, height: 330), xRadius: 90, yRadius: 90).fill()

            let parts = NSBezierPath()
            parts.appendArc(withCenter: NSPoint(x: 512, y: 408), radius: 196, startAngle: 180, endAngle: 360)
            parts.move(to: NSPoint(x: 512, y: 212))
            parts.line(to: NSPoint(x: 512, y: 158))
            parts.move(to: NSPoint(x: 380, y: 158))
            parts.line(to: NSPoint(x: 644, y: 158))
            parts.lineWidth = 48
            parts.lineCapStyle = .round
            parts.stroke()
        }
    }
}

let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
NSGraphicsContext.current?.imageInterpolation = .high
drawPlate()
drawBackdropFrame()
drawMicrophone()
image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fputs("failed to render icon\n", stderr)
    exit(1)
}

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"
try png.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
