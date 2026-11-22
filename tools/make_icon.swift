// Erzeugt icon/AppIcon.png (1024x1024) im SD-Karten-Stil
import AppKit

let S: CGFloat = 1024
let img = NSImage(size: NSSize(width: S, height: S))
img.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext

// Hintergrund: abgerundetes Quadrat mit Verlauf (macOS-Raster: 824 px Fläche, 100 px Rand)
let bg = NSRect(x: 100, y: 100, width: 824, height: 824)
let bgPath = NSBezierPath(roundedRect: bg, xRadius: 185, yRadius: 185)
ctx.saveGState()
let sh = NSShadow(); sh.shadowBlurRadius = 24; sh.shadowOffset = NSSize(width: 0, height: -10)
sh.shadowColor = NSColor.black.withAlphaComponent(0.35); sh.set()
NSColor(calibratedRed: 0.10, green: 0.42, blue: 0.95, alpha: 1).setFill(); bgPath.fill()
ctx.restoreGState()
NSGradient(starting: NSColor(calibratedRed: 0.30, green: 0.62, blue: 1.0, alpha: 1),
           ending: NSColor(calibratedRed: 0.05, green: 0.30, blue: 0.82, alpha: 1))!
    .draw(in: bgPath, angle: -90)

// SD-Karte: Rechteck mit abgeschrägter Ecke oben rechts
let cw: CGFloat = 470, ch: CGFloat = 600
let cx = (S - cw) / 2, cy: CGFloat = 200
let cut: CGFloat = 120, r: CGFloat = 36
let card = NSBezierPath()
card.move(to: NSPoint(x: cx + r, y: cy))
card.line(to: NSPoint(x: cx + cw - r, y: cy))
card.curve(to: NSPoint(x: cx + cw, y: cy + r), controlPoint1: NSPoint(x: cx + cw, y: cy), controlPoint2: NSPoint(x: cx + cw, y: cy))
card.line(to: NSPoint(x: cx + cw, y: cy + ch - cut))
card.line(to: NSPoint(x: cx + cw - cut, y: cy + ch))
card.line(to: NSPoint(x: cx + r, y: cy + ch))
card.curve(to: NSPoint(x: cx, y: cy + ch - r), controlPoint1: NSPoint(x: cx, y: cy + ch), controlPoint2: NSPoint(x: cx, y: cy + ch))
card.line(to: NSPoint(x: cx, y: cy + r))
card.curve(to: NSPoint(x: cx + r, y: cy), controlPoint1: NSPoint(x: cx, y: cy), controlPoint2: NSPoint(x: cx, y: cy))
card.close()

ctx.saveGState()
let sh2 = NSShadow(); sh2.shadowBlurRadius = 30; sh2.shadowOffset = NSSize(width: 0, height: -14)
sh2.shadowColor = NSColor.black.withAlphaComponent(0.45); sh2.set()
NSColor.black.setFill(); card.fill()
ctx.restoreGState()
NSGradient(starting: NSColor(white: 0.30, alpha: 1), ending: NSColor(white: 0.12, alpha: 1))!.draw(in: card, angle: -90)

// Goldkontakte oben
let gold = NSGradient(starting: NSColor(calibratedRed: 1.0, green: 0.86, blue: 0.45, alpha: 1),
                      ending: NSColor(calibratedRed: 0.80, green: 0.58, blue: 0.15, alpha: 1))!
let pinW: CGFloat = 38, pinH: CGFloat = 96, gap: CGFloat = 13
let pinTop = cy + ch - 34
for i in 0..<7 {
    let x = cx + 34 + CGFloat(i) * (pinW + gap)
    let topY = x + pinW > cx + cw - cut ? pinTop - (x + pinW - (cx + cw - cut)) - 10 : pinTop
    let p = NSBezierPath(roundedRect: NSRect(x: x, y: topY - pinH, width: pinW, height: pinH), xRadius: 7, yRadius: 7)
    gold.draw(in: p, angle: -90)
}

// Schreibschutz-Schieber links
NSColor(white: 0.55, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: cx - 14, y: cy + ch - 300, width: 28, height: 90), xRadius: 6, yRadius: 6).fill()

// Etikett mit "RAW"
let label = NSRect(x: cx + 50, y: cy + 70, width: cw - 100, height: 250)
let lp = NSBezierPath(roundedRect: label, xRadius: 28, yRadius: 28)
NSGradient(starting: NSColor(calibratedRed: 1.0, green: 0.55, blue: 0.20, alpha: 1),
           ending: NSColor(calibratedRed: 0.93, green: 0.30, blue: 0.12, alpha: 1))!.draw(in: lp, angle: -90)
let para = NSMutableParagraphStyle(); para.alignment = .center
let attrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 150, weight: .heavy),
    .foregroundColor: NSColor.white, .paragraphStyle: para, .kern: 4
]
let t = NSAttributedString(string: "RAW", attributes: attrs)
let th = t.size().height
t.draw(in: NSRect(x: label.minX, y: label.midY - th / 2, width: label.width, height: th))

img.unlockFocus()
let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
let png = rep.representation(using: .png, properties: [:])!
let out = URL(fileURLWithPath: CommandLine.arguments[1])
try! png.write(to: out)
print("Icon geschrieben:", out.path)
