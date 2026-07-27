//
//  SkyImageService.swift
//  EmpyreanEyes
//
//  Fetches a cutout of the sky from the SDSS SkyServer image service.
//

import CoreGraphics
import Foundation
import ImageIO

/// SDSS data releases the image cutout service is known to serve.
enum SkyServerRelease: String, CaseIterable, Sendable {
    case dr13, dr16, dr17, dr18, dr19

    static let `default`: SkyServerRelease = .dr19

    var displayName: String { rawValue.uppercased() }
}

enum SkyImageError: LocalizedError {
    case badResponse(status: Int)
    case notAnImage
    case outsideSurveyFootprint

    var errorDescription: String? {
        switch self {
        case .badResponse(let status):
            return "SkyServer returned HTTP \(status)."
        case .notAnImage:
            return "SkyServer's reply could not be decoded as an image."
        case .outsideSurveyFootprint:
            return "SDSS has no imagery for the sky overhead."
        }
    }
}

struct SkyImageService: Sendable {

    var release: SkyServerRelease = .default
    /// Arcseconds per pixel. Larger values take in more sky.
    var scale: Double = 1.0

    func imageURL(for coordinate: EquatorialCoordinate, pixelSize: CGSize) -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "skyserver.sdss.org"
        components.path = "/\(release.rawValue)/SkyServerWS/ImgCutout/getjpeg"
        components.queryItems = [
            URLQueryItem(name: "ra", value: String(format: "%.6f", coordinate.rightAscension)),
            URLQueryItem(name: "dec", value: String(format: "%.6f", coordinate.declination)),
            URLQueryItem(name: "scale", value: String(format: "%.4f", scale)),
            URLQueryItem(name: "width", value: String(Int(pixelSize.width.rounded()))),
            URLQueryItem(name: "height", value: String(Int(pixelSize.height.rounded()))),
        ]
        return components.url!
    }

    /// Downloads the cutout and returns the raw JPEG bytes.
    ///
    /// Deliberately `Data` and not `NSImage`: `NSImage` is not `Sendable`, so
    /// handing one back to the main actor fails to compile on Swift 6. Passing
    /// the bytes also skips a needless decode-and-re-encode — the JPEG goes
    /// straight to disk and straight to the desktop.
    ///
    /// Throws `.outsideSurveyFootprint` when SDSS has no imagery for the
    /// requested patch of sky.
    func fetchImageData(for coordinate: EquatorialCoordinate, pixelSize: CGSize) async throws -> Data {
        let url = imageURL(for: coordinate, pixelSize: pixelSize)

        var request = URLRequest(url: url)
        request.timeoutInterval = 60
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            // SkyServer signals "no imagery here" with a 404 carrying a small
            // placeholder JPEG, not with an error document. Reported plainly it
            // reads as a broken app rather than as the edge of the survey.
            if http.statusCode == 404 {
                throw SkyImageError.outsideSurveyFootprint
            }
            throw SkyImageError.badResponse(status: http.statusCode)
        }
        guard Self.isDecodableImage(data) else {
            throw SkyImageError.notAnImage
        }
        guard !Self.isEffectivelyBlank(data) else {
            throw SkyImageError.outsideSurveyFootprint
        }
        return data
    }

    static func isDecodableImage(_ data: Data) -> Bool {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0,
              CGImageSourceCreateImageAtIndex(source, 0, nil) != nil
        else { return false }
        return true
    }

    private static let userAgent =
        "EmpyreanEyes/\(Bundle.main.shortVersionString) (+https://github.com/skychwang/Empyrean-Eyes)"

    /// SDSS renders sky it never observed as a near-uniform black frame. Rather
    /// than hang a blank wallpaper on the wall, sample the image and report it.
    ///
    /// Sampling is done on a downscaled 32×32 thumbnail so the cost does not
    /// grow with wallpaper size.
    static func isEffectivelyBlank(_ data: Data, threshold: Double = 3.5) -> Bool {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceThumbnailMaxPixelSize: 32,
              ] as CFDictionary)
        else { return false }

        let width = thumbnail.width
        let height = thumbnail.height
        guard width > 0, height > 0 else { return false }

        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return false }

        context.draw(thumbnail, in: CGRect(x: 0, y: 0, width: width, height: height))

        var total = 0.0
        for index in stride(from: 0, to: pixels.count, by: 4) {
            let r = Double(pixels[index])
            let g = Double(pixels[index + 1])
            let b = Double(pixels[index + 2])
            total += 0.299 * r + 0.587 * g + 0.114 * b
        }
        let meanLuminance = total / Double(width * height)
        return meanLuminance < threshold
    }
}

extension Bundle {
    var shortVersionString: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }
}
