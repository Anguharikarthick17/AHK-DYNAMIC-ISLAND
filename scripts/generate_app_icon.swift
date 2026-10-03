import AppKit
import CoreGraphics
import Foundation

// MARK: - 1. Locate Source Logo Artwork
let projectDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : FileManager.default.currentDirectoryPath
let sourceLogoPath = "/Users/angu/.gemini/antigravity-ide/brain/4f13d6a6-eb88-4522-a248-42e54f0a5e80/.user_uploaded/media_1790999769347.jpg"

guard let sourceImg = NSImage(contentsOfFile: sourceLogoPath),
      let sourceRep = sourceImg.representations.first as? NSBitmapImageRep,
      let sourceCG = sourceRep.cgImage else {
    print("Error: Could not load source logo from \(sourceLogoPath)")
    exit(1)
}

print("Loaded source logo artwork: \(sourceCG.width)x\(sourceCG.height)")

// Crop compact artwork for small sizes (Capsule + AHK, omitting unreadable tiny subtext)
let compactRect = CGRect(x: 270, y: 230, width: 484, height: 300)
guard let compactCG = sourceCG.cropping(to: compactRect) else {
    print("Error cropping compact logo")
    exit(1)
}

// MARK: - 2. Render Icon at Specific Pixel Size
func renderIcon(pixelSize: Int) -> NSImage {
    let s = CGFloat(pixelSize)
    let image = NSImage(size: NSSize(width: s, height: s))
    image.lockFocus()

    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }
    ctx.interpolationQuality = .high

    // Apple Standard Squircle Sizing: ~82.4% of total canvas (centered with margin)
    let squircleScale: CGFloat = (pixelSize <= 32) ? 0.92 : 0.824
    let squircleSize = (s * squircleScale).rounded()
    let squircleOrigin = ((s - squircleSize) / 2.0).rounded()
    let squircleRect = CGRect(x: squircleOrigin, y: squircleOrigin, width: squircleSize, height: squircleSize)
    let cornerRadius = squircleSize * 0.224
    let squirclePath = CGPath(roundedRect: squircleRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

    // Ambient Drop Shadow (for >= 32px)
    if pixelSize >= 32 {
        ctx.saveGState()
        let shadowColor = NSColor.black.withAlphaComponent(0.46).cgColor
        let shadowBlur = max(1.5, s * 0.024)
        let shadowOffset = CGSize(width: 0, height: -max(1.0, s * 0.013))
        ctx.setShadow(offset: shadowOffset, blur: shadowBlur, color: shadowColor)
        ctx.addPath(squirclePath)
        ctx.setFillColor(NSColor.black.cgColor)
        ctx.fillPath()
        ctx.restoreGState()
    }

    // Clip to Squircle
    ctx.saveGState()
    ctx.addPath(squirclePath)
    ctx.clip()

    // Deep Obsidian Base Fill matching artwork black
    ctx.setFillColor(NSColor(red: 0.015, green: 0.015, blue: 0.018, alpha: 1.0).cgColor)
    ctx.fill(squircleRect)

    // Select Art Variant
    if pixelSize <= 64 {
        // Small-size optimization: Bold Capsule + AHK silhouette
        let aspect = CGFloat(compactCG.width) / CGFloat(compactCG.height)
        let margin: CGFloat = (pixelSize <= 32) ? 0.08 : 0.12
        let maxW = squircleSize * (1.0 - margin * 2)
        let maxH = squircleSize * (1.0 - margin * 2)

        var drawW = maxW
        var drawH = drawW / aspect
        if drawH > maxH {
            drawH = maxH
            drawW = drawH * aspect
        }

        let drawX = (squircleRect.midX - (drawW / 2.0)).rounded()
        let drawY = (squircleRect.midY - (drawH / 2.0)).rounded()
        ctx.draw(compactCG, in: CGRect(x: drawX, y: drawY, width: drawW, height: drawH))
    } else {
        // Large-size variant: Full logo artwork centered and scaled
        let scale: CGFloat = squircleSize / CGFloat(sourceCG.width) * 1.35
        let drawW = CGFloat(sourceCG.width) * scale
        let drawH = CGFloat(sourceCG.height) * scale
        let drawX = squircleRect.midX - (drawW / 2.0)
        let drawY = squircleRect.midY - (drawH / 2.0)
        ctx.draw(sourceCG, in: CGRect(x: drawX, y: drawY, width: drawW, height: drawH))
    }

    // Subtle Top Specular Curve on Squircle
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bevelColors = [
        NSColor(white: 1.0, alpha: 0.10).cgColor,
        NSColor(white: 1.0, alpha: 0.0).cgColor
    ] as CFArray
    if let bevelGrad = CGGradient(colorsSpace: colorSpace, colors: bevelColors, locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(
            bevelGrad,
            start: CGPoint(x: squircleRect.midX, y: squircleRect.maxY),
            end: CGPoint(x: squircleRect.midX, y: squircleRect.maxY - (squircleSize * 0.35)),
            options: []
        )
    }

    ctx.restoreGState()

    // Delicate 1pt white glass rim around perimeter
    ctx.saveGState()
    ctx.addPath(squirclePath)
    ctx.setLineWidth(max(1.0, s * 0.0025))
    ctx.setStrokeColor(NSColor(white: 1.0, alpha: 0.13).cgColor)
    ctx.strokePath()
    ctx.restoreGState()

    image.unlockFocus()
    return image
}

// MARK: - 3. Target Output Paths
let resourcesDir = "\(projectDir)/Resources"
let assetCatalogDir = "\(resourcesDir)/Assets.xcassets/AppIcon.appiconset"
let iconsetDir = "\(projectDir)/build/AppIcon.iconset"

try? FileManager.default.createDirectory(atPath: assetCatalogDir, withIntermediateDirectories: true)
try? FileManager.default.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

// Target configurations
let iconSizes: [(filename: String, pixelSize: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for item in iconSizes {
    let img = renderIcon(pixelSize: item.pixelSize)
    guard let tiff = img.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let pngData = rep.representation(using: .png, properties: [:]) else {
        print("Failed to encode PNG for \(item.filename)")
        continue
    }

    // Write to Assets.xcassets
    let assetPath = "\(assetCatalogDir)/\(item.filename)"
    try? pngData.write(to: URL(fileURLWithPath: assetPath))

    // Write to build iconset for iconutil
    let iconsetPath = "\(iconsetDir)/\(item.filename)"
    try? pngData.write(to: URL(fileURLWithPath: iconsetPath))
    print("Generated \(item.filename) (\(item.pixelSize)x\(item.pixelSize))")
}

// Also write master 1024x1024 AppIcon.png into Resources
if let masterImg = renderIcon(pixelSize: 1024).tiffRepresentation,
   let masterRep = NSBitmapImageRep(data: masterImg),
   let masterPng = masterRep.representation(using: .png, properties: [:]) {
    try? masterPng.write(to: URL(fileURLWithPath: "\(resourcesDir)/AppIcon.png"))
    print("Updated \(resourcesDir)/AppIcon.png (1024x1024)")
}

// MARK: - 4. Write Contents.json for Assets.xcassets
let contentsJSON = """
{
  "images" : [
    {
      "size" : "16x16",
      "idiom" : "mac",
      "filename" : "icon_16x16.png",
      "scale" : "1x"
    },
    {
      "size" : "16x16",
      "idiom" : "mac",
      "filename" : "icon_16x16@2x.png",
      "scale" : "2x"
    },
    {
      "size" : "32x32",
      "idiom" : "mac",
      "filename" : "icon_32x32.png",
      "scale" : "1x"
    },
    {
      "size" : "32x32",
      "idiom" : "mac",
      "filename" : "icon_32x32@2x.png",
      "scale" : "2x"
    },
    {
      "size" : "128x128",
      "idiom" : "mac",
      "filename" : "icon_128x128.png",
      "scale" : "1x"
    },
    {
      "size" : "128x128",
      "idiom" : "mac",
      "filename" : "icon_128x128@2x.png",
      "scale" : "2x"
    },
    {
      "size" : "256x256",
      "idiom" : "mac",
      "filename" : "icon_256x256.png",
      "scale" : "1x"
    },
    {
      "size" : "256x256",
      "idiom" : "mac",
      "filename" : "icon_256x256@2x.png",
      "scale" : "2x"
    },
    {
      "size" : "512x512",
      "idiom" : "mac",
      "filename" : "icon_512x512.png",
      "scale" : "1x"
    },
    {
      "size" : "512x512",
      "idiom" : "mac",
      "filename" : "icon_512x512@2x.png",
      "scale" : "2x"
    }
  ],
  "info" : {
    "version" : 1,
    "author" : "xcode"
  }
}
"""

try? contentsJSON.write(to: URL(fileURLWithPath: "\(assetCatalogDir)/Contents.json"), atomically: true, encoding: .utf8)
print("Wrote \(assetCatalogDir)/Contents.json")

// MARK: - 5. Run iconutil to create Resources/AppIcon.icns
let icnsPath = "\(resourcesDir)/AppIcon.icns"
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconsetDir, "-o", icnsPath]
try? task.run()
task.waitUntilExit()

if task.terminationStatus == 0 {
    print("Successfully compiled \(icnsPath)")
} else {
    print("iconutil failed with code \(task.terminationStatus)")
    exit(1)
}

print("==> AppIcon generation completed successfully!")
