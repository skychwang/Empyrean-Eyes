//
//  LocationProvider.swift
//  EmpyreanEyes
//
//  Wraps CLLocationManager in a one-shot async call, and falls back to a
//  manually entered position when Location Services are unavailable.
//

import CoreLocation
import Foundation

enum LocationError: LocalizedError {
    case denied
    case unavailable
    case noManualLocationSet

    var errorDescription: String? {
        switch self {
        case .denied:
            return "Location access denied — set a location in Preferences."
        case .unavailable:
            return "Could not determine your location."
        case .noManualLocationSet:
            return "Manual location is on, but no coordinates have been entered in Preferences."
        }
    }
}

@MainActor
final class LocationProvider: NSObject {

    private let manager = CLLocationManager()
    private var waiters: [CheckedContinuation<CLLocationCoordinate2D, Error>] = []

    override init() {
        super.init()
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        manager.delegate = self
    }

    /// The current coordinate, from Location Services or from Preferences.
    func currentCoordinate() async throws -> CLLocationCoordinate2D {
        if Preferences.useManualLocation {
            let latitude = Preferences.manualLatitude
            let longitude = Preferences.manualLongitude
            guard latitude != 0 || longitude != 0 else { throw LocationError.noManualLocationSet }
            return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }

        switch manager.authorizationStatus {
        case .denied, .restricted:
            throw LocationError.denied
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        default:
            break
        }

        return try await withCheckedThrowingContinuation { continuation in
            waiters.append(continuation)
            manager.requestLocation()
        }
    }

    /// Kilometre accuracy is plenty: a degree of latitude is 111 km, and the
    /// zenith moves a degree every four minutes anyway.
    private func resume(with result: Result<CLLocationCoordinate2D, Error>) {
        let pending = waiters
        waiters.removeAll()
        for continuation in pending {
            continuation.resume(with: result)
        }
    }
}

extension LocationProvider: CLLocationManagerDelegate {

    // CLLocationManager delivers callbacks on the run loop it was created on,
    // which is the main one here, so assuming main-actor isolation is sound.

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        MainActor.assumeIsolated {
            guard let coordinate = locations.last?.coordinate else {
                resume(with: .failure(LocationError.unavailable))
                return
            }
            resume(with: .success(coordinate))
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        MainActor.assumeIsolated {
            // `self.manager` rather than the callback's parameter: the two are
            // the same object, but only the property is main-actor isolated.
            let status = self.manager.authorizationStatus
            if status == .denied || status == .restricted {
                resume(with: .failure(LocationError.denied))
            } else {
                resume(with: .failure(error))
            }
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        MainActor.assumeIsolated {
            switch self.manager.authorizationStatus {
            case .denied, .restricted:
                resume(with: .failure(LocationError.denied))
            case .authorized, .authorizedAlways:
                if !waiters.isEmpty { self.manager.requestLocation() }
            default:
                break
            }
        }
    }
}
