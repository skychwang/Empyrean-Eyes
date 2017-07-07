//
//  StatusMenuController.swift
//  EmpyreanEyes
//
//  Created by Sky Wang on 7/6/17.
//  Copyright © 2017 Sky Wang. All rights reserved.
//

import Cocoa
import CoreLocation

extension CLLocationCoordinate2D {
    var latitudeMinutes:  Double {
        return latitude.multiplied(by: 3600)
            .truncatingRemainder(dividingBy: 3600)
            .divided(by: 60)
    }
    var latitudeSeconds:  Double {
        return latitude.multiplied(by: 3600)
            .truncatingRemainder(dividingBy: 3600)
            .truncatingRemainder(dividingBy: 60)
    }
    
    var longitudeMinutes: Double {
        return longitude.multiplied(by: 3600)
            .truncatingRemainder(dividingBy: 3600)
            .divided(by: 60)
    }
    var longitudeSeconds: Double {
        return longitude.multiplied(by: 3600)
            .truncatingRemainder(dividingBy: 3600)
            .truncatingRemainder(dividingBy: 60)
    }
    
    var dms:(latitude: String, longitude: String) {
        return (String(format:"%d° %d' %.4f\" %@",
                       Int(abs(latitude)),
                       Int(abs(latitudeMinutes)),
                       abs(latitudeSeconds),
                       latitude >= 0 ? "N" : "S"),
                String(format:"%d° %d' %.4f\" %@",
                       Int(abs(longitude)),
                       Int(abs(longitudeMinutes)),
                       abs(longitudeSeconds),
                       longitude >= 0 ? "E" : "W"))
    }
}

class StatusMenuController: NSObject, CLLocationManagerDelegate {
    
    @IBOutlet weak var statusMenu: NSMenu!
    let statusItem = NSStatusBar.system().statusItem(withLength: NSVariableStatusItemLength)
    var locationManager:CLLocationManager!
    var currentLocation:CLLocation?
    //var count = 0
    var ra:String = ""
    var dec:String = ""
    var astroPicURL:URL!
    //
    var screen:NSScreen!
    var rect:NSRect!
    var screenHeight:String = ""
    var screenWidth:String = ""
    
    @IBAction func quitClicked(_ sender: NSMenuItem) {
        NSApplication.shared().terminate(self)
    }
    
    @IBAction func updateClicked(_ sender: NSMenuItem) {
        updateLocation()
    }
    
    override func awakeFromNib() {
        //statusItem.title = "EmpyreanEyes"
        statusItem.menu = statusMenu
        let icon = NSImage(named: "statusIcon")
        icon?.isTemplate = true // best for dark mode
        statusItem.image = icon
        statusItem.menu = statusMenu
        //Init screen resolution size
        screen = NSScreen.main()!
        rect = screen.frame
        screenHeight = String(Int(rect.size.height))
        screenWidth = String(Int(rect.size.width))
        setupLocationManager()
    }
    
    func updateLocation() {
        self.locationManager.delegate = self
        //self.locationManager.startMonitoringSignificantLocationChanges()
        self.locationManager.startUpdatingLocation()
    }
    
    func setupLocationManager(){
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        //self.locationManager?.requestAlwaysAuthorization()
        locationManager?.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager?.startUpdatingLocation()
        
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
        //locationManager?.stopMonitoringSignificantLocationChanges()
        let locationValue:CLLocationCoordinate2D = manager.location!.coordinate
        
        //print(locationValue.latitude)//String
        //print(locationValue.dms.latitude)//Remember to change this thingy to get RA DEC
        //print(locationValue.longitude)
        //print(locationValue.dms.longitude)
        //count += 1
        //print(count)
        
        //INSERT RA DEC CONVERSION METHOD HERE
        
        ra = String(locationValue.longitude) //CHANGE THIS WHEN GET RA DEC
        dec = String(locationValue.latitude) //CHANGE THIS WHEN GET RA DEC
        
        astroPicURL = URL(string: "http://skyserver.sdss.org/dr13/SkyServerWS/ImgCutout/getjpeg?ra=" + ra + "&dec=" + dec + "&scale=0.79224&width=" + screenWidth + "&height=" + screenHeight)
        
        print(astroPicURL)
        
        locationManager?.stopUpdatingLocation()
        manager.delegate = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print(error)
    }

}
