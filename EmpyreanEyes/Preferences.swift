//
//  Preferences.swift
//  EmpyreanEyes
//

import Foundation

/// Typed access to the handful of values the app persists.
enum Preferences {

    enum Key {
        static let interval = "interval"
        static let release = "dataRelease"
        static let scale = "arcsecondsPerPixel"
        static let useManualLocation = "useManualLocation"
        static let manualLatitude = "manualLatitude"
        static let manualLongitude = "manualLongitude"
    }

    static let defaultIntervalMinutes = 30
    static let intervalRange = 1...1440

    /// The backing store. Tests point this at a scratch suite so they neither
    /// read nor clobber the running app's real preferences.
    nonisolated(unsafe) static var defaults: UserDefaults = .standard

    /// Auto-refresh interval in minutes, clamped to something sane.
    ///
    /// The default was raised from 5 minutes to 30: the sky drifts about a
    /// quarter of a degree in five minutes, which is not a visible change, and
    /// the old rate meant 288 SkyServer requests a day per user.
    static var intervalMinutes: Int {
        get {
            guard let stored = defaults.object(forKey: Key.interval) else {
                return defaultIntervalMinutes
            }
            let value = (stored as? Int) ?? Int(stored as? String ?? "") ?? defaultIntervalMinutes
            return min(max(value, intervalRange.lowerBound), intervalRange.upperBound)
        }
        set {
            let clamped = min(max(newValue, intervalRange.lowerBound), intervalRange.upperBound)
            defaults.set(clamped, forKey: Key.interval)
        }
    }

    static var release: SkyServerRelease {
        get {
            guard let raw = defaults.string(forKey: Key.release),
                  let release = SkyServerRelease(rawValue: raw)
            else { return .default }
            return release
        }
        set { defaults.set(newValue.rawValue, forKey: Key.release) }
    }

    /// Arcseconds per pixel — how much sky one wallpaper pixel covers.
    static var arcsecondsPerPixel: Double {
        get {
            let value = defaults.double(forKey: Key.scale)
            return value > 0 ? value : 1.0
        }
        set { defaults.set(max(0.1, min(newValue, 60)), forKey: Key.scale) }
    }

    /// Set when the user would rather name a spot than grant Location Services.
    static var useManualLocation: Bool {
        get { defaults.bool(forKey: Key.useManualLocation) }
        set { defaults.set(newValue, forKey: Key.useManualLocation) }
    }

    static var manualLatitude: Double {
        get { defaults.double(forKey: Key.manualLatitude) }
        set { defaults.set(min(max(newValue, -90), 90), forKey: Key.manualLatitude) }
    }

    static var manualLongitude: Double {
        get { defaults.double(forKey: Key.manualLongitude) }
        set { defaults.set(min(max(newValue, -180), 180), forKey: Key.manualLongitude) }
    }
}
