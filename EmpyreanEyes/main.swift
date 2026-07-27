//
//  main.swift
//  EmpyreanEyes
//
//  An explicit entry point instead of a MainMenu nib. The app has no windows of
//  its own and no main menu, so there is nothing for a nib to carry.
//

import AppKit

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate

// Menu bar only: no Dock tile, no app switcher entry. `LSUIElement` in
// Info.plist says the same thing; setting it here keeps the two from drifting.
application.setActivationPolicy(.accessory)
application.run()
