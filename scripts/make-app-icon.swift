#!/usr/bin/env swift
// Generates the 1024 px app icon (green background, white check mark, no alpha, no text).
//
//   swift scripts/make-app-icon.swift App/Habitat/Assets.xcassets/AppIcon.appiconset/AppIcon.png
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024
guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: make-app-icon.swift <output.png>\n".utf8))
    exit(64)
}
let space = CGColorSpace(name: CGColorSpace.sRGB)!
guard let ctx = CGContext(
    data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: space,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
) else { exit(1) }

// Background: vertical gradient, light green to deep green.
let colors = [
    CGColor(red: 0.30, green: 0.78, blue: 0.47, alpha: 1),
    CGColor(red: 0.07, green: 0.48, blue: 0.29, alpha: 1)
] as CFArray
let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1])!
ctx.drawLinearGradient(
    gradient, start: CGPoint(x: 0, y: CGFloat(size)), end: CGPoint(x: 0, y: 0), options: []
)

// Check mark.
let path = CGMutablePath()
path.move(to: CGPoint(x: 270, y: 530))
path.addLine(to: CGPoint(x: 450, y: 350))
path.addLine(to: CGPoint(x: 770, y: 700))
ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
ctx.setLineWidth(110)
ctx.setLineCap(.round)
ctx.setLineJoin(.round)
ctx.addPath(path)
ctx.strokePath()

guard let image = ctx.makeImage(),
      let dest = CGImageDestinationCreateWithURL(
          URL(fileURLWithPath: CommandLine.arguments[1]) as CFURL, UTType.png.identifier as CFString, 1, nil
      ) else { exit(1) }
CGImageDestinationAddImage(dest, image, nil)
guard CGImageDestinationFinalize(dest) else { exit(1) }
