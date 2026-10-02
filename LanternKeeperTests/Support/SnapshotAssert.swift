import SwiftUI
import UIKit
import XCTest

/// Minimal snapshot testing with Apple frameworks only.
///
/// References live in `LanternKeeperTests/__Snapshots__`. A missing reference is recorded and
/// the test fails once, so new snapshots are always reviewed. Set `TEST_RUNNER_SNAPSHOT_RECORD=1`
/// when running `xcodebuild test` to re-record everything.
@MainActor
func assertSnapshot<V: View>(
    _ view: V,
    named name: String,
    size: CGSize = CGSize(width: 390, height: 844),
    scale: CGFloat = 2,
    tolerance: Double = 0.005,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    guard let image = render(view, size: size, scale: scale) else {
        return XCTFail("Could not render \(name)", file: file, line: line)
    }

    let directory = URL(fileURLWithPath: "\(file)").deletingLastPathComponent().appendingPathComponent("__Snapshots__")
    let url = directory.appendingPathComponent("\(name).png")
    let record = ProcessInfo.processInfo.environment["SNAPSHOT_RECORD"] == "1"

    if record || !FileManager.default.fileExists(atPath: url.path) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try XCTUnwrap(image.pngData()).write(to: url)
        } catch {
            return XCTFail("Could not record \(name): \(error)", file: file, line: line)
        }
        return XCTFail("Recorded snapshot \(name). Review it, then run again.", file: file, line: line)
    }

    guard let reference = UIImage(contentsOfFile: url.path) else {
        return XCTFail("Unreadable reference \(name)", file: file, line: line)
    }
    let difference = pixelDifference(image, reference)
    if difference > tolerance {
        let attachment = XCTAttachment(image: image)
        attachment.name = "\(name)-actual"
        attachment.lifetime = .keepAlways
        XCTContext.runActivity(named: "Snapshot mismatch: \(name)") { $0.add(attachment) }
        XCTFail(
            "Snapshot \(name) differs by \(String(format: "%.2f", difference * 100))% of pixels",
            file: file, line: line
        )
    }
}

@MainActor
private func render<V: View>(_ view: V, size: CGSize, scale: CGFloat) -> UIImage? {
    let controller = UIHostingController(rootView: view.frame(width: size.width, height: size.height))
    let window = UIWindow(frame: CGRect(origin: .zero, size: size))
    window.rootViewController = controller
    window.isHidden = false
    controller.view.frame = window.bounds
    controller.view.setNeedsLayout()
    controller.view.layoutIfNeeded()

    let format = UIGraphicsImageRendererFormat()
    format.scale = scale
    format.opaque = true
    format.preferredRange = .standard
    let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
        controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
    }
    window.isHidden = true
    return image
}

/// Fraction of pixels whose channels differ by more than a small tolerance.
private func pixelDifference(_ a: UIImage, _ b: UIImage) -> Double {
    guard let first = a.cgImage, let second = b.cgImage,
          first.width == second.width, first.height == second.height
    else { return 1 }

    func pixels(_ image: CGImage) -> [UInt8] {
        let width = image.width, height = image.height
        var buffer = [UInt8](repeating: 0, count: width * height * 4)
        buffer.withUnsafeMutableBytes { raw in
            let context = CGContext(
                data: raw.baseAddress, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
            context?.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        return buffer
    }

    let lhs = pixels(first), rhs = pixels(second)
    var differing = 0
    var index = 0
    while index < lhs.count {
        for channel in 0..<4 where abs(Int(lhs[index + channel]) - Int(rhs[index + channel])) > 3 {
            differing += 1
            break
        }
        index += 4
    }
    return Double(differing) / Double(lhs.count / 4)
}
