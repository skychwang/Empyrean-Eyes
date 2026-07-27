//
//  SkyCalculator.swift
//  EmpyreanEyes
//
//  Converts a place and a moment into the equatorial coordinates of the zenith:
//  the point on the celestial sphere directly overhead.
//
//  The sidereal time formulae follow the U.S. Naval Observatory's
//  "Approximate Sidereal Time" note:
//  https://aa.usno.navy.mil/faq/GAST
//

import Foundation

/// A point on the celestial sphere, in degrees.
struct EquatorialCoordinate: Equatable, Sendable {
    /// Right ascension, normalised to `0..<360` degrees.
    var rightAscension: Double
    /// Declination, in `-90...90` degrees.
    var declination: Double
}

/// Pure, testable astronomy. No I/O, no clock of its own — pass the date in.
enum SkyCalculator {

    /// Julian Date of the UNIX epoch, 1970-01-01 00:00:00 UTC.
    static let julianDayAtUnixEpoch = 2_440_587.5
    /// Julian Date of the J2000.0 epoch, 2000-01-01 12:00:00 TT.
    static let julianDayAtJ2000 = 2_451_545.0

    static func julianDay(from date: Date) -> Double {
        julianDayAtUnixEpoch + date.timeIntervalSince1970 / 86_400
    }

    /// Greenwich Mean Sidereal Time, in hours, normalised to `0..<24`.
    static func greenwichMeanSiderealTime(at date: Date) -> Double {
        let julianDayNow = julianDay(from: date)

        // Julian Date of the preceding midnight UT. Because Julian days begin at
        // noon, flooring `JD + 0.5` and subtracting it back lands on 0h UT.
        let julianDayAtMidnight = (julianDayNow + 0.5).rounded(.down) - 0.5

        // Hours of UT elapsed since that midnight. The original implementation
        // used only the integer hour here, which biased every result by up to a
        // full hour (30 minutes on average).
        let hoursSinceMidnight = (julianDayNow - julianDayAtMidnight) * 24

        let daysSinceJ2000AtMidnight = julianDayAtMidnight - julianDayAtJ2000
        let daysSinceJ2000 = julianDayNow - julianDayAtJ2000
        let centuriesSinceJ2000 = daysSinceJ2000 / 36_525

        let gmst = 6.697374558
            + 0.065_709_824_419_08 * daysSinceJ2000AtMidnight
            + 1.002_737_909_35 * hoursSinceMidnight
            + 0.000026 * centuriesSinceJ2000 * centuriesSinceJ2000

        return normalizedHours(gmst)
    }

    /// Greenwich Apparent Sidereal Time, in hours, normalised to `0..<24`.
    ///
    /// GAST is GMST plus the equation of the equinoxes, a nutation correction
    /// worth at most about a second of time.
    static func greenwichApparentSiderealTime(at date: Date) -> Double {
        let daysSinceJ2000 = julianDay(from: date) - julianDayAtJ2000

        // Longitude of the ascending node of the Moon's mean orbit.
        let omega = 125.04 - 0.052954 * daysSinceJ2000
        // Mean longitude of the Sun.
        let sunLongitude = 280.47 + 0.98565 * daysSinceJ2000
        // Obliquity of the ecliptic.
        let obliquity = 23.4393 - 0.0000004 * daysSinceJ2000

        // These arguments are in degrees; `sin` and `cos` take radians. The
        // original implementation fed degrees straight in.
        let nutationInLongitude = -0.000319 * sin(radians(omega))
            - 0.000024 * sin(radians(2 * sunLongitude))
        let equationOfEquinoxes = nutationInLongitude * cos(radians(obliquity))

        return normalizedHours(greenwichMeanSiderealTime(at: date) + equationOfEquinoxes)
    }

    /// Local Apparent Sidereal Time, in hours, normalised to `0..<24`.
    ///
    /// Local sidereal time *is* the right ascension of the local meridian, and
    /// the zenith sits on the meridian by definition.
    static func localApparentSiderealTime(at date: Date, longitude: Double) -> Double {
        normalizedHours(greenwichApparentSiderealTime(at: date) + longitude / 15)
    }

    /// The equatorial coordinates of the zenith above `latitude`/`longitude`.
    ///
    /// - Note: Right ascension is returned in **degrees**, which is what image
    ///   servers such as SDSS SkyServer expect. Sidereal time is conventionally
    ///   expressed in hours, so it is multiplied by 15 on the way out. The
    ///   original implementation passed the hour value through unconverted,
    ///   which confined every request to a 24°-wide sliver of sky rather than
    ///   the sky actually overhead.
    static func zenith(at date: Date, latitude: Double, longitude: Double) -> EquatorialCoordinate {
        let siderealHours = localApparentSiderealTime(at: date, longitude: longitude)
        return EquatorialCoordinate(
            rightAscension: normalizedDegrees(siderealHours * 15),
            declination: min(max(latitude, -90), 90)
        )
    }

    // MARK: - Helpers

    static func radians(_ degrees: Double) -> Double { degrees * .pi / 180 }

    /// Wraps an hour angle into `0..<24`, correctly handling negatives.
    static func normalizedHours(_ hours: Double) -> Double {
        let wrapped = hours.truncatingRemainder(dividingBy: 24)
        return wrapped < 0 ? wrapped + 24 : wrapped
    }

    /// Wraps an angle into `0..<360`, correctly handling negatives.
    static func normalizedDegrees(_ degrees: Double) -> Double {
        let wrapped = degrees.truncatingRemainder(dividingBy: 360)
        return wrapped < 0 ? wrapped + 360 : wrapped
    }
}

extension EquatorialCoordinate {
    /// Sexagesimal rendering, e.g. `13h 29m 52.7s  +47° 11' 43"`.
    var displayString: String {
        let hours = rightAscension / 15
        let h = Int(hours)
        let minutesTotal = (hours - Double(h)) * 60
        let m = Int(minutesTotal)
        let s = (minutesTotal - Double(m)) * 60

        let absDec = abs(declination)
        let d = Int(absDec)
        let decMinutesTotal = (absDec - Double(d)) * 60
        let dm = Int(decMinutesTotal)
        let ds = (decMinutesTotal - Double(dm)) * 60

        return String(
            format: "%02dh %02dm %04.1fs  %@%02d° %02d' %02.0f\"",
            h, m, s, declination < 0 ? "−" : "+", d, dm, ds
        )
    }
}
