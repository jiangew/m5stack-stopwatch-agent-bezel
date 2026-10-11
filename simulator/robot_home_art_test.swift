// Run on macOS; decodes the actual shipped JPEGs, not layout mocks.
import Foundation
import CoreGraphics
import ImageIO

let root = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "assets/robot-home/generated"
var failures = 0
for name in ["bumblebee", "optimus", "megatron", "starscream"] {
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
    // The old saturated circle must be absent from the outer annulus.
    // The original source remains untouched; these are the firmware derivatives.
    var missing = 0
    for degrees in stride(from: 0, to: 360, by: 2) {
        let angle = Double(degrees) * .pi / 180
        let found = (138...145).contains { radius in
            let x = Int((149.5 + Double(radius) * cos(angle)).rounded())
            let y = Int((149.5 + Double(radius) * sin(angle)).rounded())
            let offset = (y * 300 + x) * 4
            let rgb = pixels[offset..<(offset + 3)].map(Int.init)
            return rgb.max()! >= 75 && rgb.max()! - rgb.min()! >= 40
        }
        if !found { missing += 1 }
    }
    if missing != 180 {
        print("FAIL \(name): \(180-missing) outer-ring sectors remain")
        failures += 1
    } else {
        print("PASS \(name): no outer ring, 300x300")
    }
}
exit(failures == 0 ? 0 : 1)
