// Run on macOS; decodes the actual shipped JPEGs, not layout mocks.
import Foundation
import CoreGraphics
import ImageIO

let root = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "assets/robot-home"
var failures = 0
for name in ["bumblebee", "optimus", "megatron", "starscream"] {
    let url = URL(fileURLWithPath: root).appendingPathComponent(name + ".jpg")
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
    // A clipped or substantially off-center ring leaves an angular gap.
    // Allow antialiasing and small art variations, but require every 2-degree
    // sector to contain the saturated outer rim within a centered annulus.
    var missing = 0
    for degrees in stride(from: 0, to: 360, by: 2) {
        let angle = Double(degrees) * .pi / 180
        let found = (122...145).contains { radius in
            let x = Int((149.5 + Double(radius) * cos(angle)).rounded())
            let y = Int((149.5 + Double(radius) * sin(angle)).rounded())
            let offset = (y * 300 + x) * 4
            let rgb = pixels[offset..<(offset + 3)].map(Int.init)
            return rgb.max()! >= 75 && rgb.max()! - rgb.min()! >= 40
        }
        if !found { missing += 1 }
    }
    if missing > 0 {
        print("FAIL \(name): \(missing) outer-ring sectors missing")
        failures += 1
    } else {
        print("PASS \(name): complete centered ring, 300x300")
    }
}
exit(failures == 0 ? 0 : 1)
