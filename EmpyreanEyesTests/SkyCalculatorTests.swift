//
//  SkyCalculatorTests.swift
//  EmpyreanEyesTests
//
//  Reference sidereal times were generated independently with astropy 5.1
//  (`Time(...).sidereal_time(...)`), not with the code under test.
//

import AppKit
import Foundation
import Testing

@testable import EmpyreanEyes

private func date(_ iso: String) -> Date {
    let formatter = ISO8601DateFormatter()
    formatter.timeZone = TimeZone(identifier: "UTC")
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: iso)!
}

/// One second of time is 1/3600 h. The USNO approximation is quoted as good to
/// 0.1 s this century; the slack here also absorbs the UT1−UTC offset, which
/// astropy accounts for and this app deliberately does not.
private let hourTolerance = 1.0 / 3600.0 * 3.6

@Suite("Julian dates")
struct JulianDayTests {

    @Test("J2000.0 epoch is JD 2451545.0")
    func j2000() {
        #expect(abs(SkyCalculator.julianDay(from: date("2000-01-01T12:00:00Z")) - 2_451_545.0) < 1e-6)
    }

    @Test("UNIX epoch is JD 2440587.5")
    func unixEpoch() {
        #expect(abs(SkyCalculator.julianDay(from: Date(timeIntervalSince1970: 0)) - 2_440_587.5) < 1e-6)
    }

    @Test("A day later is a Julian day later")
    func oneDayLater() {
        let start = date("2026-07-27T00:00:00Z")
        let later = start.addingTimeInterval(86_400)
        let delta = SkyCalculator.julianDay(from: later) - SkyCalculator.julianDay(from: start)
        #expect(abs(delta - 1.0) < 1e-9)
    }
}

@Suite("Sidereal time")
struct SiderealTimeTests {

    @Test("GMST at J2000.0 is 18h 41m 50.55s", arguments: [
        ("2000-01-01T12:00:00Z", 18.697_374_83),
        ("2026-07-27T00:00:00Z", 20.312_656_54),
        ("2026-01-15T18:30:00Z", 2.181_311_71),
        ("2026-03-20T09:45:30Z", 21.621_139_93),
    ])
    func gmstMatchesReference(iso: String, expected: Double) {
        let gmst = SkyCalculator.greenwichMeanSiderealTime(at: date(iso))
        #expect(abs(gmst - expected) < hourTolerance)
    }

    @Test("GAST matches reference", arguments: [
        ("2000-01-01T12:00:00Z", 18.697_138_16),
        ("2026-07-27T00:00:00Z", 20.312_814_70),
        ("2026-01-15T18:30:00Z", 2.181_420_06),
        ("2026-03-20T09:45:30Z", 21.621_246_06),
    ])
    func gastMatchesReference(iso: String, expected: Double) {
        let gast = SkyCalculator.greenwichApparentSiderealTime(at: date(iso))
        #expect(abs(gast - expected) < hourTolerance)
    }

    /// The original code took only the integer hour of UT, so every result
    /// inside a given clock hour was identical. Sidereal time must advance.
    @Test("Sidereal time advances within a single clock hour")
    func advancesWithinTheHour() {
        let base = date("2026-07-27T14:00:00Z")
        let quarterPast = base.addingTimeInterval(15 * 60)
        let delta = SkyCalculator.greenwichMeanSiderealTime(at: quarterPast)
            - SkyCalculator.greenwichMeanSiderealTime(at: base)
        // 15 minutes of solar time is 15 minutes of sidereal time plus a hair.
        #expect(abs(delta - 0.25 * 1.002_737_909_35) < 1e-6)
    }

    @Test("Sidereal time stays in 0..<24")
    func staysInRange() {
        var moment = date("2026-01-01T00:00:00Z")
        for _ in 0..<400 {
            let gast = SkyCalculator.greenwichApparentSiderealTime(at: moment)
            #expect(gast >= 0 && gast < 24)
            moment = moment.addingTimeInterval(3_671)
        }
    }
}

@Suite("Zenith coordinates")
struct ZenithTests {

    @Test("Zenith matches reference for real places", arguments: [
        ("2026-07-27T00:00:00Z", 40.7128, -74.0060, 230.686_220),   // New York
        ("2026-01-15T18:30:00Z", 51.4779, 0.0, 32.721_301),         // Greenwich
        ("2026-03-20T09:45:30Z", -33.8688, 151.2093, 115.527_991),  // Sydney
    ])
    func zenithMatchesReference(iso: String, latitude: Double, longitude: Double, expectedRA: Double) {
        let zenith = SkyCalculator.zenith(at: date(iso), latitude: latitude, longitude: longitude)
        // 0.06° of RA is 3.6 s of time, the tolerance above expressed as an angle.
        #expect(abs(zenith.rightAscension - expectedRA) < 0.06)
        #expect(abs(zenith.declination - latitude) < 1e-9)
    }

    /// Declination at the zenith is the observer's latitude, by definition.
    @Test("Declination tracks latitude", arguments: [-89.0, -33.9, 0.0, 40.7, 89.0])
    func declinationIsLatitude(latitude: Double) {
        let zenith = SkyCalculator.zenith(at: date("2026-07-27T00:00:00Z"), latitude: latitude, longitude: 12)
        #expect(abs(zenith.declination - latitude) < 1e-9)
    }

    /// A far-west longitude used to drive right ascension negative, and a
    /// negative `ra` is rejected by SkyServer.
    @Test("Right ascension stays in 0..<360 at every longitude")
    func rightAscensionNeverNegative() {
        for longitudeStep in -180...180 {
            let longitude = Double(longitudeStep)
            for hourStep in 0..<24 {
                let moment = date("2026-07-27T00:00:00Z").addingTimeInterval(Double(hourStep) * 3_600)
                let zenith = SkyCalculator.zenith(at: moment, latitude: 0, longitude: longitude)
                #expect(zenith.rightAscension >= 0 && zenith.rightAscension < 360)
            }
        }
    }

    /// Right ascension is reported in degrees because that is what SkyServer
    /// wants. Passing sidereal hours through unconverted — the original bug —
    /// pins every request inside a 24°-wide strip.
    @Test("Right ascension spans the whole circle over a day")
    func spansFullCircle() {
        var minimum = Double.infinity
        var maximum = -Double.infinity
        let start = date("2026-07-27T00:00:00Z")
        for minuteStep in stride(from: 0, to: 24 * 60, by: 10) {
            let moment = start.addingTimeInterval(Double(minuteStep) * 60)
            let ra = SkyCalculator.zenith(at: moment, latitude: 40.7, longitude: -74).rightAscension
            minimum = min(minimum, ra)
            maximum = max(maximum, ra)
        }
        #expect(minimum < 5)
        #expect(maximum > 355)
    }
}

@Suite("SkyServer requests")
@MainActor
struct SkyImageServiceTests {

    @Test("URL carries degrees and pixel dimensions")
    func urlIsWellFormed() {
        let service = SkyImageService(release: .dr19, scale: 1.5)
        let coordinate = EquatorialCoordinate(rightAscension: 202.4696, declination: 47.1952)
        let url = service.imageURL(for: coordinate, pixelSize: CGSize(width: 3456, height: 2234))

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        let query = Dictionary(
            uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") }
        )

        #expect(components.host == "skyserver.sdss.org")
        #expect(components.path.contains("dr19"))
        #expect(query["ra"] == "202.469600")
        #expect(query["dec"] == "47.195200")
        #expect(query["scale"] == "1.5000")
        #expect(query["width"] == "3456")
        #expect(query["height"] == "2234")
    }

    @Test("Every known release builds a valid URL", arguments: SkyServerRelease.allCases)
    func allReleases(release: SkyServerRelease) {
        let service = SkyImageService(release: release, scale: 1)
        let url = service.imageURL(
            for: EquatorialCoordinate(rightAscension: 180, declination: 25),
            pixelSize: CGSize(width: 512, height: 512)
        )
        #expect(url.absoluteString.contains("/\(release.rawValue)/"))
    }

    /// SkyServer answers a request for unobserved sky with HTTP 404 carrying a
    /// placeholder JPEG. Surfacing that verbatim reads as a broken app.
    @Test("A 404 is reported as missing coverage, not as a transport error")
    func notFoundMeansNoCoverage() {
        let error = SkyImageError.outsideSurveyFootprint
        #expect(error.errorDescription?.contains("no imagery") == true)

        let transport = SkyImageError.badResponse(status: 503)
        #expect(transport.errorDescription?.contains("503") == true)
    }

    @Test("A solid black frame reads as outside the footprint")
    func blankDetection() throws {
        let blank = try #require(solidColorJPEG(white: 0))
        #expect(SkyImageService.isEffectivelyBlank(blank))
    }

    @Test("A bright frame does not read as blank")
    func brightIsNotBlank() throws {
        let bright = try #require(solidColorJPEG(white: 0.5))
        #expect(!SkyImageService.isEffectivelyBlank(bright))
    }

    @Test("Real image data decodes; junk does not")
    func decodability() throws {
        let jpeg = try #require(solidColorJPEG(white: 0.5))
        #expect(SkyImageService.isDecodableImage(jpeg))
        #expect(!SkyImageService.isDecodableImage(Data("not an image".utf8)))
        #expect(!SkyImageService.isDecodableImage(Data()))
    }

    private func solidColorJPEG(white: CGFloat) -> Data? {
        let size = NSSize(width: 64, height: 64)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor(white: white, alpha: 1).drawSwatch(in: NSRect(origin: .zero, size: size))
        image.unlockFocus()

        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff)
        else { return nil }
        return bitmap.representation(using: .jpeg, properties: [:])
    }
}

/// Runs against a scratch defaults suite rather than the real one, so the tests
/// neither read nor overwrite the preferences of an installed copy of the app.
@Suite("Preferences", .serialized)
struct PreferencesTests {

    private let suiteName = "me.skywang.EmpyreanEyes.tests"

    private func withScratchDefaults(_ body: () -> Void) {
        let scratch = UserDefaults(suiteName: suiteName)!
        scratch.removePersistentDomain(forName: suiteName)
        let previous = Preferences.defaults
        Preferences.defaults = scratch
        defer {
            Preferences.defaults = previous
            scratch.removePersistentDomain(forName: suiteName)
        }
        body()
    }

    @Test("Interval is clamped into range")
    func intervalClamping() {
        withScratchDefaults {
            Preferences.intervalMinutes = 0
            #expect(Preferences.intervalMinutes == Preferences.intervalRange.lowerBound)

            Preferences.intervalMinutes = 999_999
            #expect(Preferences.intervalMinutes == Preferences.intervalRange.upperBound)

            Preferences.intervalMinutes = 45
            #expect(Preferences.intervalMinutes == 45)
        }
    }

    @Test("Unset interval falls back to the default")
    func intervalDefault() {
        withScratchDefaults {
            #expect(Preferences.intervalMinutes == Preferences.defaultIntervalMinutes)
        }
    }

    /// Builds before 2.0 stored the interval as a string. Those values have to
    /// keep working after an upgrade.
    @Test("A legacy string interval is still readable")
    func legacyStringInterval() {
        withScratchDefaults {
            Preferences.defaults.set("17", forKey: Preferences.Key.interval)
            #expect(Preferences.intervalMinutes == 17)
        }
    }

    @Test("Unset data release falls back to the newest")
    func releaseDefault() {
        withScratchDefaults {
            #expect(Preferences.release == .dr19)
            Preferences.release = .dr13
            #expect(Preferences.release == .dr13)
        }
    }

    @Test("Manual coordinates are clamped to valid ranges")
    func coordinateClamping() {
        withScratchDefaults {
            Preferences.manualLatitude = 300
            #expect(Preferences.manualLatitude == 90)
            Preferences.manualLongitude = -400
            #expect(Preferences.manualLongitude == -180)
        }
    }
}

@Suite("Screen geometry")
@MainActor
struct WallpaperSetterTests {

    @Test("Oversized displays are capped without distorting the aspect ratio")
    func capping() {
        // Stand-in for a 6K Retina panel: 6016×3384 physical pixels.
        let width = 6016.0
        let height = 3384.0
        let longest = max(width, height)
        let factor = WallpaperSetter.maximumPixelDimension / longest
        let capped = CGSize(width: (width * factor).rounded(), height: (height * factor).rounded())

        #expect(max(capped.width, capped.height) <= WallpaperSetter.maximumPixelDimension)
        #expect(abs(capped.width / capped.height - width / height) < 0.01)
    }
}
