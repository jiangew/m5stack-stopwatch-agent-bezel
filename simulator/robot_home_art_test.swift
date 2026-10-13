// Run on macOS; independently decodes the actual shipped JPEGs via ImageIO.
import Foundation
import CoreGraphics
import ImageIO

let root = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "assets/robot-home/generated"
let names = ["bumblebee", "bumblebeefullbody", "optimus", "jazz", "hotrod", "wheeljack", "hound", "ironhide", "ratchet"]
var portraits = [[UInt8]]()
var failures = 0
for name in names {
    let url = URL(fileURLWithPath: root).appendingPathComponent(name + "-idle.jpg")
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
          image.width == 300, image.height == 300 else {
        fatalError("\(name): expected decodable 300x300 portrait")
    }
    var pixels = [UInt8](repeating: 0, count: 300 * 300 * 4)
    pixels.withUnsafeMutableBytes { storage in
        let context = CGContext(data: storage.baseAddress, width: 300, height: 300,
            bitsPerComponent: 8, bytesPerRow: 1200,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: 300, height: 300))
    }
    var maximumEdge = 0
    var visiblePixels = 0
    for y in 0..<300 {
        for x in 0..<300 {
            let offset = (y * 300 + x) * 4
            let maximum = Int(max(pixels[offset], pixels[offset + 1], pixels[offset + 2]))
            if x < 18 || x >= 282 || y < 18 || y >= 282 {
                maximumEdge = max(maximumEdge, maximum)
            }
            if maximum > 70 { visiblePixels += 1 }
        }
    }
    if maximumEdge > 12 || visiblePixels <= 6000 {
        print("FAIL \(name): margin RGB max=\(maximumEdge), visible pixels=\(visiblePixels)")
        failures += 1
    } else {
        print("PASS \(name): ImageIO 300x300 decode, black 18px edges, visible portrait")
    }
    portraits.append(pixels)
}
for first in 0..<portraits.count {
    for second in (first + 1)..<portraits.count {
        if portraits[first] == portraits[second] {
            print("FAIL \(names[first])/\(names[second]): duplicated portrait identity")
            failures += 1
        }
    }
}
exit(failures == 0 ? 0 : 1)
