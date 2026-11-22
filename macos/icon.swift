// Draws the app icon (the favicon's three CAM blocks + green checkpoint) at every iconset size.
import AppKit
let out = CommandLine.arguments[1]
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)
func draw(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px) / 1024, c = { (h: UInt32) in NSColor(srgbRed: CGFloat(h >> 16 & 255)/255, green: CGFloat(h >> 8 & 255)/255, blue: CGFloat(h & 255)/255, alpha: 1) }
    // macOS icon grid: 824pt squircle-ish tile centred in 1024 with a soft shadow
    let tile = NSRect(x: 100*s, y: 100*s, width: 824*s, height: 824*s)
    let sh = NSShadow(); sh.shadowColor = .black.withAlphaComponent(0.35); sh.shadowBlurRadius = 24*s; sh.shadowOffset = NSSize(width: 0, height: -10*s)
    NSGraphicsContext.saveGraphicsState(); sh.set()
    let path = NSBezierPath(roundedRect: tile, xRadius: 185*s, yRadius: 185*s)
    NSGradient(starting: c(0x2a2c32), ending: c(0x141518))!.draw(in: path, angle: -90)
    NSGraphicsContext.restoreGraphicsState()
    let bw: CGFloat = 196*s, bh: CGFloat = 150*s, y: CGFloat = 470*s, x0: CGFloat = 512*s - 1.5*bw
    for (i, col) in [0xecc94b, 0x7fa8ff, 0xff7385].enumerated() {
        c(UInt32(col)).setFill()
        NSBezierPath(roundedRect: NSRect(x: x0 + CGFloat(i)*bw + 6*s, y: y, width: bw - 12*s, height: bh), xRadius: 22*s, yRadius: 22*s).fill()
    }
    c(0x62d692).setFill()
    NSBezierPath(ovalIn: NSRect(x: x0 + 3*bw - 58*s, y: y - 150*s, width: 92*s, height: 92*s)).fill()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}
for b in [16, 32, 128, 256, 512] {
    try! draw(b).write(to: URL(fileURLWithPath: "\(out)/icon_\(b)x\(b).png"))
    try! draw(b*2).write(to: URL(fileURLWithPath: "\(out)/icon_\(b)x\(b)@2x.png"))
}
