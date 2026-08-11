//
//  ImageOps.swift
//  Stash
//
//  Created by Francisco Juan on 11/08/26.
//

import Foundation
import ImageIO
import UniformTypeIdentifiers
import Vision

enum ImageOps {
    /// Converts TIFF (or any source) data to PNG data.
    nonisolated static func convertToPNG(_ data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        let mutable = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(mutable, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return mutable as Data
    }

    /// Creates a small JPEG thumbnail for list previews.
    nonisolated static func makeThumbnail(data: Data, maxPixel: Int = 240) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let thumb = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let mutable = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(mutable, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, thumb, [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return mutable as Data
    }

    /// Downscales an image and re-encodes as JPEG at the given quality.
    nonisolated static func compressed(data: Data, maxDimension: Int = 1600, quality: CGFloat = 0.7) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let mutable = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(mutable, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return mutable as Data
    }

    /// Recognizes text in an image using the Vision framework.
    nonisolated static func ocrText(data: Data) async -> String? {
        await Task.detached(priority: .utility) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(data: data, options: [:])
            do {
                try handler.perform([request])
                let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
                return lines.isEmpty ? nil : lines.joined(separator: "\n")
            } catch {
                return nil
            }
        }.value
    }
}
