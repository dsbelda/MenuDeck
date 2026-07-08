#!/usr/bin/env swift
// Run with: swift scripts/generate-icon.swift
// Generates AppIcon.png (1024x1024) in Sources/Clutch/Assets/

import AppKit
import CoreGraphics

let outputDir = "Sources/Clutch/Assets"
let outputPath = "\(outputDir)/AppIcon.png"

// --- Canvas setup ---
let size = 1024
let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: size, pixelsHigh: size,
    bitsPerSample: 8, samplesPerPixel: 4,
    hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0, bitsPerPixel: 0
)!
let ctx = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.current = ctx
let cg = ctx.cgContext
let rect = CGRect(x: 0, y: 0, width: size, height: size)

// --- Background: rounded rect with the app's violet gradient ---
let radius = CGFloat(size) * 0.22
let bgPath = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
cg.addPath(bgPath)
cg.clip()

let gradColors = [
    NSColor(red: 0.62, green: 0.32, blue: 1.0, alpha: 1).cgColor,
    NSColor(red: 0.40, green: 0.18, blue: 0.88, alpha: 1).cgColor,
]
let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                           colors: gradColors as CFArray,
                           locations: [0.0, 1.0])!
cg.drawLinearGradient(gradient,
                       start: CGPoint(x: 0, y: CGFloat(size)),
                       end: CGPoint(x: CGFloat(size), y: 0),
                       options: [])
cg.resetClip()

// --- Clutch mark: three parallel diagonal bars (grip texture) ---
let contentSize = CGFloat(size) * 0.76
let barLength = contentSize * 0.92
let barThickness = contentSize * 0.20
let spacing = contentSize * 0.34
let center = CGPoint(x: size / 2, y: size / 2)

NSGraphicsContext.saveGraphicsState()
let transform = NSAffineTransform()
transform.translateX(by: center.x, yBy: center.y)
transform.rotate(byDegrees: 45)
transform.concat()

for i in -1...1 {
    let y = CGFloat(i) * spacing
    let barRect = CGRect(x: -barLength / 2, y: y - barThickness / 2,
                          width: barLength, height: barThickness)
    let bar = NSBezierPath(roundedRect: barRect, xRadius: barThickness / 2, yRadius: barThickness / 2)
    NSColor.white.setFill()
    bar.fill()
}
NSGraphicsContext.restoreGraphicsState()

// --- Save ---
let fm = FileManager.default
try! fm.createDirectory(atPath: outputDir, withIntermediateDirectories: true)
let pngData = rep.representation(using: .png, properties: [:])!
try! pngData.write(to: URL(fileURLWithPath: outputPath))
print("✓ Icon saved to \(outputPath)  (\(size)×\(size) px)")
