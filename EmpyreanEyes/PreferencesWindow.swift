//
//  PreferencesWindow.swift
//  EmpyreanEyes
//
//  Created by Sky Wang on 7/8/17.
//  Copyright © 2017 Sky Wang. All rights reserved.
//

import Cocoa

protocol PreferencesWindowDelegate {
    func preferencesDidUpdate()
}

class PreferencesWindow: NSWindowController, NSWindowDelegate {
    
    @IBOutlet weak var intervalTextField: NSTextField!
    var delegate: PreferencesWindowDelegate?
    
    override var windowNibName : String! {
        return "PreferencesWindow"
    }

    override func windowDidLoad() {
        super.windowDidLoad()
        
        self.window?.center()
        self.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        let defaults = UserDefaults.standard
        let interval = defaults.string(forKey: "interval") ?? DEFAULT_INTERVAL
        intervalTextField.stringValue = interval
    }
    
    func windowWillClose(_ notification: Notification) {
        let defaults = UserDefaults.standard
        defaults.setValue(intervalTextField.stringValue, forKey: "interval")
        delegate?.preferencesDidUpdate()
    }
    
}
