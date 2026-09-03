import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let S: CGFloat = 1024

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 0xFF)/255, green: CGFloat((hex >> 8) & 0xFF)/255,
            blue: CGFloat(hex & 0xFF)/255, alpha: a)
}

func makeContext() -> CGContext {
    CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0,
              space: CGColorSpace(name: CGColorSpace.sRGB)!,
              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
}

func gradient(_ ctx: CGContext, _ top: UInt32, _ bottom: UInt32) {
    let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                       colors: [rgb(top), rgb(bottom)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: S), end: CGPoint(x: 0, y: 0), options: [])
}

/// 45度傾けたタグ（角丸四角＋吊り穴）。CG は y が上向きなので、
/// 穴を上の角に持ってくるには時計回り（負の角度）に回す。
func drawTag(_ ctx: CGContext, size: CGFloat, center: CGPoint, fill: CGColor, hole: CGColor) {
    ctx.saveGState()
    ctx.translateBy(x: center.x, y: center.y)
    ctx.rotate(by: -.pi / 4)
    let r = CGRect(x: -size/2, y: -size/2, width: size, height: size)
    ctx.addPath(CGPath(roundedRect: r, cornerWidth: size * 0.22, cornerHeight: size * 0.22, transform: nil))
    ctx.setFillColor(fill)
    ctx.fillPath()
    ctx.setFillColor(hole)
    ctx.addArc(center: CGPoint(x: r.minX + size * 0.30, y: r.maxY - size * 0.30),
               radius: size * 0.115, startAngle: 0, endAngle: .pi * 2, clockwise: false)
    ctx.fillPath()
    ctx.restoreGState()
}

func drawWaves(_ ctx: CGContext, center: CGPoint, color: CGColor, radii: [CGFloat], lineWidth: CGFloat) {
    ctx.setStrokeColor(color)
    ctx.setLineWidth(lineWidth)
    ctx.setLineCap(.round)
    for r in radii {
        ctx.addArc(center: center, radius: r, startAngle: -.pi/4.6, endAngle: .pi/4.6, clockwise: false)
        ctx.strokePath()
    }
}

func write(_ ctx: CGContext, _ path: String) {
    let dest = CGImageDestinationCreateWithURL(
        URL(fileURLWithPath: path) as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
    CGImageDestinationFinalize(dest)
    print("wrote \(path)")
}

/// 3種とも同じ配置。色だけ差し替える。
func render(background: (UInt32, UInt32), tag: UInt32, hole: UInt32, wave: UInt32, to path: String) {
    let ctx = makeContext()
    gradient(ctx, background.0, background.1)
    let center = CGPoint(x: S * 0.38, y: S / 2)
    drawTag(ctx, size: 440, center: center, fill: rgb(tag), hole: rgb(hole))
    drawWaves(ctx, center: CGPoint(x: S * 0.26, y: S / 2), color: rgb(wave),
              radii: [S * 0.40, S * 0.49, S * 0.58], lineWidth: 48)
    write(ctx, path)
}

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."

// ライト: アプリのアクセント色そのまま
render(background: (0x00909C, 0x00606A), tag: 0xFFFFFF, hole: 0x007781, wave: 0xFFFFFF,
       to: "\(out)/AppIcon.png")

// ダーク: 背景を沈ませ、マークは明るいまま残す
render(background: (0x0A3138, 0x02171B), tag: 0xE6F4F5, hole: 0x0A3138, wave: 0xE6F4F5,
       to: "\(out)/AppIcon-Dark.png")

// ティント: iOS が輝度に色を乗せるのでグレースケールで作る
render(background: (0x1A1A1A, 0x000000), tag: 0xFFFFFF, hole: 0x1A1A1A, wave: 0xFFFFFF,
       to: "\(out)/AppIcon-Tinted.png")
