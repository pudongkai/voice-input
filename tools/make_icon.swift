import AppKit

let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

// 透明背景 + 圆角蓝色渐变
let bgRect = NSRect(x: 72, y: 72, width: size - 144, height: size - 144)
let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: 190, yRadius: 190)
let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.10, green: 0.30, blue: 0.92, alpha: 1),
    NSColor(calibratedRed: 0.29, green: 0.62, blue: 1.00, alpha: 1)
])!
gradient.draw(in: bgPath, angle: -55)

// 顶部柔光
NSColor.white.withAlphaComponent(0.10).setFill()
NSBezierPath(roundedRect: NSRect(x: 120, y: 560, width: 784, height: 300), xRadius: 150, yRadius: 150).fill()

// 麦克风
NSColor.white.setFill()
NSColor.white.setStroke()

let body = NSBezierPath(
    roundedRect: NSRect(x: 422, y: 408, width: 180, height: 330),
    xRadius: 90,
    yRadius: 90
)
body.fill()

let cradle = NSBezierPath()
cradle.appendArc(withCenter: NSPoint(x: 512, y: 408), radius: 196, startAngle: 180, endAngle: 360)
cradle.lineWidth = 48
cradle.lineCapStyle = .round
cradle.stroke()

let stem = NSBezierPath()
stem.move(to: NSPoint(x: 512, y: 212))
stem.line(to: NSPoint(x: 512, y: 158))
stem.lineWidth = 48
stem.lineCapStyle = .round
stem.stroke()

let base = NSBezierPath()
base.move(to: NSPoint(x: 380, y: 158))
base.line(to: NSPoint(x: 644, y: 158))
base.lineWidth = 48
base.lineCapStyle = .round
base.stroke()

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
