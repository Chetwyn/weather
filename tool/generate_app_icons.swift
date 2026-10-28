// 从单张源图生成 iOS / Android 应用图标资源。
//
// 用法：swift tool/generate_app_icons.swift <源图.png> <仓库根目录>
//
// 不直接缩放源图：源图四角透明、背景是自中心向外衰减的暗色渐变，
// 直接压到实色底上会留一圈比背景更暗的「光晕」。这里把白色云形按覆盖率抠成
// 带 alpha 的图层，再合成到纯色 #1B2942 方形底上——图形本身不改，只换底。
// iOS 图标不允许 alpha 通道，Android 自适应图标的前景层则必须是透明底。

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let background = (r: 0x1B, g: 0x29, b: 0x42) // 与应用夜间主题一致的深墨蓝
let cloudColor = (r: 0xF2, g: 0xF4, b: 0xF6) // 云体平均色

guard CommandLine.arguments.count == 3 else {
    print("usage: swift tool/generate_app_icons.swift <source.png> <repo-root>")
    exit(2)
}
let sourcePath = CommandLine.arguments[1]
let repoRoot = CommandLine.arguments[2]

// MARK: - 读取源图

guard
    let imageSource = CGImageSourceCreateWithURL(
        URL(fileURLWithPath: sourcePath) as CFURL, nil),
    let sourceImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
else {
    print("无法读取源图：\(sourcePath)")
    exit(1)
}

let width = sourceImage.width
let height = sourceImage.height
var pixels = [UInt8](repeating: 0, count: width * height * 4)
guard
    let readContext = CGContext(
        data: &pixels,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
else {
    print("无法创建位图上下文")
    exit(1)
}
readContext.draw(sourceImage, in: CGRect(x: 0, y: 0, width: width, height: height))

// MARK: - 抠出云形图层（按覆盖率得到抗锯齿 alpha）

var layer = [UInt8](repeating: 0, count: width * height * 4)
var minX = width, minY = height, maxX = 0, maxY = 0
for y in 0..<height {
    for x in 0..<width {
        let i = (y * width + x) * 4
        let channelMin = Double(min(pixels[i], min(pixels[i + 1], pixels[i + 2]))) / 255
        // 背景最亮处约为 0.15，云体约 0.95；两段之间线性映射即可保留边缘渐隐
        let coverage = max(0, min(1, (channelMin - 0.12) / 0.75))
        if coverage > 0.5 {
            minX = min(minX, x)
            maxX = max(maxX, x)
            minY = min(minY, y)
            maxY = max(maxY, y)
        }
        let alpha = UInt8((coverage * 255).rounded())
        layer[i] = UInt8((Double(cloudColor.r) * coverage).rounded())
        layer[i + 1] = UInt8((Double(cloudColor.g) * coverage).rounded())
        layer[i + 2] = UInt8((Double(cloudColor.b) * coverage).rounded())
        layer[i + 3] = alpha
    }
}

let cloudRect = CGRect(
    x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)

guard
    let layerContext = CGContext(
        data: &layer,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
    let cloudLayer = layerContext.makeImage()
else {
    print("无法生成云形图层")
    exit(1)
}

print("源图 \(width)x\(height)，云形包围盒 \(Int(cloudRect.width))x\(Int(cloudRect.height))")
print(
    "横向占比 \(String(format: "%.1f", cloudRect.width / CGFloat(width) * 100))%，"
        + "纵向占比 \(String(format: "%.1f", cloudRect.height / CGFloat(height) * 100))%")

// MARK: - 合成

let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
let solidBackground = CGColor(
    srgbRed: CGFloat(background.r) / 255,
    green: CGFloat(background.g) / 255,
    blue: CGFloat(background.b) / 255,
    alpha: 1)

/// 完整方形图标：纯色底 + 原构图（保留源图的留白比例），输出无 alpha。
func makeIcon(size: Int) -> CGImage {
    let ctx = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: srgb,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    ctx.interpolationQuality = .high
    ctx.setFillColor(solidBackground)
    ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
    ctx.draw(cloudLayer, in: CGRect(x: 0, y: 0, width: size, height: size))
    return ctx.makeImage()!
}

/// 自适应图标前景层：透明底，云形缩到画布宽度的 `fraction`，几何中心对齐画布中心。
func makeForeground(size: Int, fraction: CGFloat) -> CGImage {
    let scale = CGFloat(size) * fraction / cloudRect.width
    let side = CGFloat(width) * scale
    let originX = CGFloat(size) / 2 - cloudRect.midX * scale
    let originY = CGFloat(size) / 2 - side + cloudRect.midY * scale
    let ctx = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: srgb,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    ctx.draw(
        cloudLayer,
        in: CGRect(x: originX, y: originY, width: side, height: side))
    return ctx.makeImage()!
}

func writePNG(_ image: CGImage, to relativePath: String) {
    let url = URL(fileURLWithPath: repoRoot).appendingPathComponent(relativePath)
    try? FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    guard
        let destination = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.png.identifier as CFString, 1, nil)
    else {
        print("无法写入 \(relativePath)")
        exit(1)
    }
    CGImageDestinationAddImage(destination, image, nil)
    if !CGImageDestinationFinalize(destination) {
        print("写入失败 \(relativePath)")
        exit(1)
    }
    print("  \(relativePath) \(image.width)x\(image.height)")
}

// MARK: - iOS

let iosIcons: [(String, Int)] = [
    ("Icon-App-20x20@1x.png", 20),
    ("Icon-App-20x20@2x.png", 40),
    ("Icon-App-20x20@3x.png", 60),
    ("Icon-App-29x29@1x.png", 29),
    ("Icon-App-29x29@2x.png", 58),
    ("Icon-App-29x29@3x.png", 87),
    ("Icon-App-40x40@1x.png", 40),
    ("Icon-App-40x40@2x.png", 80),
    ("Icon-App-40x40@3x.png", 120),
    ("Icon-App-60x60@2x.png", 120),
    ("Icon-App-60x60@3x.png", 180),
    ("Icon-App-76x76@1x.png", 76),
    ("Icon-App-76x76@2x.png", 152),
    ("Icon-App-83.5x83.5@2x.png", 167),
    ("Icon-App-1024x1024@1x.png", 1024),
]

print("iOS AppIcon.appiconset")
for (name, size) in iosIcons {
    writePNG(
        makeIcon(size: size),
        to: "ios/Runner/Assets.xcassets/AppIcon.appiconset/\(name)")
}

// MARK: - Android

let androidDensities: [(String, Int)] = [
    ("mdpi", 48),
    ("hdpi", 72),
    ("xhdpi", 96),
    ("xxhdpi", 144),
    ("xxxhdpi", 192),
]

print("Android 传统启动图标（API 24–25）")
for (density, size) in androidDensities {
    writePNG(
        makeIcon(size: size),
        to: "android/app/src/main/res/mipmap-\(density)/ic_launcher.png")
}

// 自适应图标画布为 108dp，云形控制在 64%（约 69dp），既落在 72dp 安全圆内，
// 又和传统图标的视觉重量接近
print("Android 自适应图标前景层（API 26+）")
for (density, dp) in androidDensities {
    writePNG(
        makeForeground(size: Int(Double(dp) * 108.0 / 48.0), fraction: 0.64),
        to: "android/app/src/main/res/mipmap-\(density)/ic_launcher_foreground.png")
}

print("完成")
