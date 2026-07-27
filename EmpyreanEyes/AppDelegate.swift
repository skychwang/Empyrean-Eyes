//
//  AppDelegate.swift
//  EmpyreanEyes
//

import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private let statusMenuController = StatusMenuController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusMenuController.start()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }
}
