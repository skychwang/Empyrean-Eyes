//
//  PreferencesWindowController.swift
//  EmpyreanEyes
//
//  Built in code rather than in a nib, so it picks up whatever the current
//  system appearance and layout metrics happen to be.
//

import AppKit

@MainActor
final class PreferencesWindowController: NSWindowController {

    private let onChange: () -> Void

    private let intervalField = NSTextField()
    private let scaleField = NSTextField()
    private let releasePopUp = NSPopUpButton()
    private let manualLocationCheckbox = NSButton()
    private let latitudeField = NSTextField()
    private let longitudeField = NSTextField()

    init(onChange: @escaping () -> Void) {
        self.onChange = onChange

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 260),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Empyrean Eyes Preferences"
        window.isReleasedWhenClosed = false

        super.init(window: window)

        window.delegate = self
        window.contentView = buildContentView()
        window.center()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func showWindow(_ sender: Any?) {
        loadValues()
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(sender)
    }

    // MARK: - Layout

    private func buildContentView() -> NSView {
        let grid = NSGridView(views: [
            [label("Refresh every"), intervalRow()],
            [label("Arcsec / pixel"), configure(scaleField, width: 90)],
            [label("Data release"), releasePopUp],
            [NSGridCell.emptyContentView, manualLocationCheckbox],
            [label("Latitude"), configure(latitudeField, width: 120)],
            [label("Longitude"), configure(longitudeField, width: 120)],
        ])
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.rowSpacing = 10
        grid.columnSpacing = 12
        grid.column(at: 0).xPlacement = .trailing

        releasePopUp.removeAllItems()
        releasePopUp.addItems(withTitles: SkyServerRelease.allCases.map(\.displayName))

        manualLocationCheckbox.setButtonType(.switch)
        manualLocationCheckbox.title = "Set my location manually"
        manualLocationCheckbox.target = self
        manualLocationCheckbox.action = #selector(manualLocationToggled)

        let footnote = NSTextField(wrappingLabelWithString:
            "Empyrean Eyes points at the zenith — the sky directly overhead. "
            + "SDSS only imaged part of the sky, so some places see nothing but black.")
        footnote.font = .preferredFont(forTextStyle: .caption1)
        footnote.textColor = .secondaryLabelColor
        footnote.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.addSubview(grid)
        container.addSubview(footnote)

        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            grid.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            grid.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -20),

            footnote.topAnchor.constraint(equalTo: grid.bottomAnchor, constant: 18),
            footnote.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            footnote.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            footnote.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -16),
        ])
        return container
    }

    private func intervalRow() -> NSView {
        let stack = NSStackView(views: [
            configure(intervalField, width: 70),
            label("minutes"),
        ])
        stack.orientation = .horizontal
        stack.spacing = 6
        return stack
    }

    private func label(_ text: String) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.alignment = .right
        return field
    }

    private func configure(_ field: NSTextField, width: CGFloat) -> NSTextField {
        field.translatesAutoresizingMaskIntoConstraints = false
        field.widthAnchor.constraint(equalToConstant: width).isActive = true
        field.alignment = .right
        return field
    }

    // MARK: - Values

    private func loadValues() {
        intervalField.stringValue = String(Preferences.intervalMinutes)
        scaleField.stringValue = String(format: "%g", Preferences.arcsecondsPerPixel)
        releasePopUp.selectItem(withTitle: Preferences.release.displayName)
        manualLocationCheckbox.state = Preferences.useManualLocation ? .on : .off
        latitudeField.stringValue = String(format: "%g", Preferences.manualLatitude)
        longitudeField.stringValue = String(format: "%g", Preferences.manualLongitude)
        updateManualFieldsEnabled()
    }

    /// Reads every field back into `Preferences`. Values that will not parse are
    /// left at whatever was already stored rather than silently zeroed.
    private func saveValues() {
        if let interval = Int(intervalField.stringValue.trimmingCharacters(in: .whitespaces)) {
            Preferences.intervalMinutes = interval
        }
        if let scale = Double(scaleField.stringValue.trimmingCharacters(in: .whitespaces)) {
            Preferences.arcsecondsPerPixel = scale
        }
        if let title = releasePopUp.titleOfSelectedItem,
           let release = SkyServerRelease(rawValue: title.lowercased()) {
            Preferences.release = release
        }
        Preferences.useManualLocation = manualLocationCheckbox.state == .on
        if let latitude = Double(latitudeField.stringValue.trimmingCharacters(in: .whitespaces)) {
            Preferences.manualLatitude = latitude
        }
        if let longitude = Double(longitudeField.stringValue.trimmingCharacters(in: .whitespaces)) {
            Preferences.manualLongitude = longitude
        }
        onChange()
    }

    @objc private func manualLocationToggled() {
        updateManualFieldsEnabled()
    }

    private func updateManualFieldsEnabled() {
        let enabled = manualLocationCheckbox.state == .on
        latitudeField.isEnabled = enabled
        longitudeField.isEnabled = enabled
    }
}

extension PreferencesWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        // Commit whatever field still has focus before reading the values back.
        window?.makeFirstResponder(nil)
        saveValues()
    }
}
