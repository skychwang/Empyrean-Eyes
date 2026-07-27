//
//  StatusMenuController.swift
//  EmpyreanEyes
//
//  Owns the menu bar item and drives the update cycle.
//

import AppKit
import CoreLocation
import OSLog
import ServiceManagement

@MainActor
final class StatusMenuController: NSObject {

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let locationProvider = LocationProvider()
    private let logger = Logger(subsystem: "me.skywang.EmpyreanEyes", category: "updates")

    private lazy var preferencesWindowController = PreferencesWindowController { [weak self] in
        self?.restartTimer()
    }

    private var timer: Timer?
    private var updateTask: Task<Void, Never>?

    private let statusMessageItem = NSMenuItem()
    private let lastUpdatedItem = NSMenuItem()
    private let launchAtLoginItem = NSMenuItem()

    /// Menu width follows its longest item, so a wordy status line stretches the
    /// whole menu across the screen. Show a clipped version and hang the full
    /// text off the tooltip.
    private static let statusLineLimit = 52

    private var statusMessage = "Starting up…" {
        didSet {
            statusMessageItem.title = statusMessage.count > Self.statusLineLimit
                ? statusMessage.prefix(Self.statusLineLimit - 1).trimmingCharacters(in: .whitespaces) + "…"
                : statusMessage
            statusMessageItem.toolTip = statusMessage
        }
    }

    private var lastUpdated: Date? {
        didSet {
            guard let lastUpdated else {
                lastUpdatedItem.title = "Never updated"
                return
            }
            lastUpdatedItem.title = "Updated \(Self.timestampFormatter.string(from: lastUpdated))"
        }
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }()

    // MARK: - Setup

    func start() {
        configureStatusItem()
        statusMessage = "Starting up…"
        lastUpdated = nil
        restartTimer()
        updateNow()
    }

    private func configureStatusItem() {
        if let button = statusItem.button {
            let icon = NSImage(named: "statusIcon")
            icon?.isTemplate = true
            icon?.size = NSSize(width: 18, height: 18)
            button.image = icon
            button.image?.accessibilityDescription = "Empyrean Eyes"
        }
        statusItem.menu = buildMenu()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let updateItem = NSMenuItem(
            title: "Update Now",
            action: #selector(updateClicked),
            keyEquivalent: "r"
        )
        updateItem.target = self
        menu.addItem(updateItem)

        menu.addItem(.separator())

        statusMessageItem.title = statusMessage
        statusMessageItem.isEnabled = false
        menu.addItem(statusMessageItem)

        lastUpdatedItem.title = "Never updated"
        lastUpdatedItem.isEnabled = false
        menu.addItem(lastUpdatedItem)

        menu.addItem(.separator())

        let revealItem = NSMenuItem(
            title: "Show Current Image in Finder",
            action: #selector(revealClicked),
            keyEquivalent: ""
        )
        revealItem.target = self
        menu.addItem(revealItem)

        launchAtLoginItem.title = "Launch at Login"
        launchAtLoginItem.action = #selector(toggleLaunchAtLogin)
        launchAtLoginItem.target = self
        launchAtLoginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(launchAtLoginItem)

        let preferencesItem = NSMenuItem(
            title: "Preferences…",
            action: #selector(preferencesClicked),
            keyEquivalent: ","
        )
        preferencesItem.target = self
        menu.addItem(preferencesItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit Empyrean Eyes",
            action: #selector(quitClicked),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    // MARK: - Actions

    @objc private func updateClicked() { updateNow() }

    @objc private func preferencesClicked() {
        NSApp.activate(ignoringOtherApps: true)
        preferencesWindowController.showWindow(nil)
    }

    @objc private func quitClicked() { NSApp.terminate(self) }

    @objc private func revealClicked() {
        guard let directory = try? WallpaperSetter.imageDirectory() else { return }
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: directory.path)
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            logger.error("Launch at login toggle failed: \(error.localizedDescription)")
            statusMessage = "Could not change launch-at-login setting."
        }
        launchAtLoginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    // MARK: - Update cycle

    private func restartTimer() {
        timer?.invalidate()
        let interval = TimeInterval(Preferences.intervalMinutes) * 60
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            Task { @MainActor [weak self] in self?.updateNow() }
        }
        timer.tolerance = interval * 0.1
        self.timer = timer
    }

    private func updateNow() {
        guard updateTask == nil else { return }
        updateTask = Task { [weak self] in
            await self?.performUpdate()
            self?.updateTask = nil
        }
    }

    private func performUpdate() async {
        statusMessage = "Locating…"

        let coordinate: CLLocationCoordinate2D
        do {
            coordinate = try await locationProvider.currentCoordinate()
        } catch {
            report(error, prefix: "Location")
            return
        }

        let zenith = SkyCalculator.zenith(
            at: Date(),
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
        statusMessage = "Zenith \(zenith.displayString)"

        let service = SkyImageService(
            release: Preferences.release,
            scale: Preferences.arcsecondsPerPixel
        )

        let screens = NSScreen.screens
        guard !screens.isEmpty else {
            statusMessage = "No displays attached."
            return
        }

        // One download per distinct pixel size, reused across matching screens.
        var imagesBySize: [String: URL] = [:]
        var appliedURLs: Set<URL> = []
        let token = String(Int(Date().timeIntervalSince1970))

        for (index, screen) in screens.enumerated() {
            let size = WallpaperSetter.pixelSize(of: screen)
            let key = "\(Int(size.width))x\(Int(size.height))"

            do {
                let fileURL: URL
                if let existing = imagesBySize[key] {
                    fileURL = existing
                } else {
                    statusMessage = "Fetching \(key) view of the sky…"
                    let image = try await service.fetchImage(for: zenith, pixelSize: size)
                    fileURL = try WallpaperSetter.writeImage(image, token: "\(token)-\(index)-\(key)")
                    imagesBySize[key] = fileURL
                }
                try WallpaperSetter.apply(fileURL, to: screen)
                appliedURLs.insert(fileURL)
            } catch SkyImageError.outsideSurveyFootprint {
                // Not a per-display fault, so it gets no display prefix.
                report(SkyImageError.outsideSurveyFootprint, prefix: "No coverage")
                return
            } catch {
                report(error, prefix: "Display \(index + 1)")
                return
            }
        }

        WallpaperSetter.pruneOldImages(keeping: appliedURLs)

        lastUpdated = Date()
        statusMessage = "Zenith \(zenith.displayString)"
        logger.info("Wallpaper updated for \(screens.count) display(s).")
    }

    private func report(_ error: Error, prefix: String) {
        let message = error.localizedDescription
        statusMessage = "\(prefix): \(message)"
        logger.error("\(prefix) failure: \(message)")
    }
}
