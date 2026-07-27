//
//  WallpaperSetter.swift
//  EmpyreanEyes
//
//  Writes fetched sky images to disk and hangs them on every display.
//

import AppKit
import Foundation

@MainActor
enum WallpaperSetter {

    /// SDSS will render larger frames, but past this the download cost stops
    /// buying visible detail on any shipping display.
    static let maximumPixelDimension: CGFloat = 4096

    /// The pixel — not point — dimensions of a screen, capped for sanity.
    ///
    /// `NSScreen.frame` is measured in points. On a Retina display that is half
    /// the real pixel count, so asking SDSS for the point size yields a
    /// half-resolution wallpaper that macOS then upscales into mush.
    static func pixelSize(of screen: NSScreen) -> CGSize {
        let scale = screen.backingScaleFactor
        var width = screen.frame.width * scale
        var height = screen.frame.height * scale

        let longestSide = max(width, height)
        if longestSide > maximumPixelDimension {
            let factor = maximumPixelDimension / longestSide
            width *= factor
            height *= factor
        }
        return CGSize(width: width.rounded(), height: height.rounded())
    }

    /// Directory the generated wallpapers live in.
    ///
    /// Application Support rather than Documents: these are app-managed files
    /// the user never asked to keep, and the Caches directory can be purged out
    /// from under a wallpaper that is still on screen.
    static func imageDirectory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appendingPathComponent("EmpyreanEyes", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    /// Writes the downloaded JPEG under a name unique to this update.
    ///
    /// The name has to change every time. macOS keys its desktop-picture cache
    /// on the file URL, so overwriting one fixed path leaves the old wallpaper
    /// on screen — the bug that made the original app look like it had stopped
    /// working after its first update.
    ///
    /// The bytes are written as they arrived. Decoding and re-encoding to PNG,
    /// as this once did, cost time and turned a ~500 KB download into a 6 MB
    /// file without recovering any detail the JPEG had already discarded.
    static func writeImage(_ data: Data, token: String) throws -> URL {
        let url = try imageDirectory().appendingPathComponent("sky-\(token).jpg")
        try data.write(to: url, options: .atomic)
        return url
    }

    /// Applies `url` as the desktop picture of `screen`.
    static func apply(_ url: URL, to screen: NSScreen) throws {
        let workspace = NSWorkspace.shared
        var options = workspace.desktopImageOptions(for: screen) ?? [:]
        options[.imageScaling] = NSNumber(value: NSImageScaling.scaleProportionallyUpOrDown.rawValue)
        options[.allowClipping] = true
        try workspace.setDesktopImageURL(url, for: screen, options: options)
    }

    /// Deletes previously generated wallpapers, sparing anything currently in use.
    ///
    /// `png` is still swept up: versions before 2.0.1 wrote PNGs here.
    static func pruneOldImages(keeping inUse: Set<URL>) {
        guard let directory = try? imageDirectory() else { return }
        let keep = Set(inUse.map(\.standardizedFileURL.path))
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )) ?? []

        for url in contents where ["jpg", "png"].contains(url.pathExtension) {
            guard !keep.contains(url.standardizedFileURL.path) else { continue }
            try? FileManager.default.removeItem(at: url)
        }
    }
}
