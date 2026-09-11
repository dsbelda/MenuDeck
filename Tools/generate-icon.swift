#!/usr/bin/env swift
//
//  Renders Sources/MenuDeck/Assets/AppIcon.png from the same mark the menu bar
//  draws, so the icon and the status item can never drift apart.
//
//  Usage:  swift Tools/generate-icon.swift
//  Then:   make icon      (rebuilds AppIcon.icns from the PNG)
//
//  SwiftUI's ImageRenderer is used rather than raw Core Graphics for one
//  reason: RoundedRectangle(style: .continuous) is the only API that gives the
//  real squircle Apple's icon grid uses. A circular corner at the same radius
//  reads subtly wrong next to other Dock icons.

import SwiftUI
import AppKit

// MARK: – The mark (mirrors MenuDeckGlyph.unitTiles)

private let unitTiles: [CGRect] = [
    CGRect(x: 0,    y: 0,    width: 0.56, height: 1.00),   // expanded panel
    CGRect(x: 0.68, y: 0,    width: 0.32, height: 0.44),   // tile
    CGRect(x: 0.68, y: 0.56, width: 0.32, height: 0.44),   // tile
]

struct IconView: View {
    /// Apple's macOS grid: the rounded body fills ~82% of the canvas, leaving
    /// transparent margin for the shadow the system draws around it.
    static let canvas: CGFloat = 1024
    static let body: CGFloat = 824
    /// The squircle radius Apple uses for macOS app icons, as a fraction of the
    /// body: 185.4/824.
    static let cornerFraction: CGFloat = 0.225
    /// The mark's share of the body.
    static let markFraction: CGFloat = 0.52

    var body: some View {
        ZStack {
            squircle
            mark
        }
        .frame(width: Self.canvas, height: Self.canvas)
    }

    private var squircle: some View {
        RoundedRectangle(cornerRadius: Self.body * Self.cornerFraction, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.66, green: 0.38, blue: 1.00),
                        Color(red: 0.36, green: 0.14, blue: 0.86),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            // A hairline of light along the top edge; without it the flat fill
            // looks printed on rather than lit.
            .overlay(
                RoundedRectangle(cornerRadius: Self.body * Self.cornerFraction, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.35), .white.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: Self.body * 0.006
                    )
            )
            .frame(width: Self.body, height: Self.body)
    }

    private var mark: some View {
        let side = Self.body * Self.markFraction
        let radius = side * 0.13
        return ZStack(alignment: .topLeading) {
            ForEach(Array(unitTiles.enumerated()), id: \.offset) { _, tile in
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(.white)
                    .frame(width: tile.width * side, height: tile.height * side)
                    .offset(x: tile.minX * side, y: tile.minY * side)
            }
        }
        .frame(width: side, height: side, alignment: .topLeading)
        .shadow(color: .black.opacity(0.18), radius: side * 0.03, y: side * 0.012)
    }
}

// MARK: – Render

let outputPath = FileManager.default.currentDirectoryPath
    + "/Sources/MenuDeck/Assets/AppIcon.png"

MainActor.assumeIsolated {
    let renderer = ImageRenderer(content: IconView())
    renderer.scale = 1

    guard let nsImage = renderer.nsImage,
          let tiff = nsImage.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:])
    else {
        FileHandle.standardError.write(Data("Failed to render the icon.\n".utf8))
        exit(1)
    }

    do {
        try png.write(to: URL(fileURLWithPath: outputPath))
        print("Wrote \(outputPath) (\(bitmap.pixelsWide)×\(bitmap.pixelsHigh))")
    } catch {
        FileHandle.standardError.write(Data("Write failed: \(error)\n".utf8))
        exit(1)
    }
}
