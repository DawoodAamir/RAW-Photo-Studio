import AppKit

let root = URL(fileURLWithPath: CommandLine.arguments[1])
let output = root.appendingPathComponent("Resources/Assets.xcassets/AppIcon.appiconset")
var entries: [[String: String]] = []
func render(_ dimension: Int, _ filename: String, mac: Bool) throws {
  let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: dimension, pixelsHigh: dimension, bitsPerSample: 8,
    samplesPerPixel: mac ? 4 : 3, hasAlpha: mac, isPlanar: false, colorSpaceName: .deviceRGB,
    bytesPerRow: 0, bitsPerPixel: 0)!
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
  let transform = NSAffineTransform()
  transform.scale(by: CGFloat(dimension) / 1024)
  transform.concat()
  NSColor(calibratedRed: 0.18, green: 0.2, blue: 0.24, alpha: 1).setFill()
  (mac
    ? NSBezierPath(
      roundedRect: NSRect(x: 40, y: 40, width: 944, height: 944), xRadius: 200, yRadius: 200)
    : NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1024, height: 1024))).fill()
  NSColor(calibratedRed: 0.94, green: 0.72, blue: 0.35, alpha: 1).setStroke()
  let ring = NSBezierPath(ovalIn: NSRect(x: 220, y: 220, width: 584, height: 584))
  ring.lineWidth = 42
  ring.stroke()
  for index in 0..<6 {
    NSGraphicsContext.saveGraphicsState()
    let rotate = NSAffineTransform()
    rotate.translateX(by: 512, yBy: 512)
    rotate.rotate(byDegrees: CGFloat(index) * 60)
    rotate.concat()
    NSColor(calibratedWhite: 0.94, alpha: 1).setFill()
    let blade = NSBezierPath()
    blade.move(to: NSPoint(x: 0, y: 230))
    blade.line(to: NSPoint(x: 190, y: 110))
    blade.line(to: NSPoint(x: 105, y: -35))
    blade.line(to: NSPoint(x: 0, y: 70))
    blade.close()
    blade.fill()
    NSGraphicsContext.restoreGraphicsState()
  }
  NSGraphicsContext.restoreGraphicsState()
  try bitmap.representation(using: .png, properties: [:])!.write(
    to: output.appendingPathComponent(filename))
}
for size in [16, 32, 128, 256, 512] {
  for scale in [1, 2] {
    let name = "icon-\(size)-\(scale).png"
    try render(size * scale, name, mac: true)
    entries.append([
      "idiom": "mac", "size": "\(size)x\(size)", "scale": "\(scale)x", "filename": name,
    ])
  }
}
try render(1024, "ios-1024.png", mac: false)
entries.append([
  "idiom": "universal", "platform": "ios", "size": "1024x1024", "filename": "ios-1024.png",
])
try JSONSerialization.data(
  withJSONObject: ["images": entries, "info": ["version": 1, "author": "xcode"]],
  options: [.prettyPrinted, .sortedKeys]
).write(to: output.appendingPathComponent("Contents.json"))
