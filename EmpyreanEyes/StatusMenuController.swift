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

extension NSImage {
    var pngData: Data? {
        guard let tiffRepresentation = tiffRepresentation, let bitmapImage = NSBitmapImageRep(data: tiffRepresentation) else { return nil }
        return bitmapImage.representation(using: .PNG, properties: [:])
    }
    func pngWrite(to url: URL, options: Data.WritingOptions = .atomic) -> Bool {
        do {
            try pngData?.write(to: url, options: options)
            return true
        } catch {
            print(error.localizedDescription)
            return false
        }
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
    var screen:NSScreen!
    var rect:NSRect!
    var screenHeight:String = ""
    var screenWidth:String = ""
    var image:NSImage!
    var data:Data!
    var workspace = NSWorkspace.shared()
    
    @IBAction func quitClicked(_ sender: NSMenuItem) {
        NSApplication.shared().terminate(self)
    }
    
    @IBAction func updateClicked(_ sender: NSMenuItem) {
        updateLocation()
    }
    
    func jdFromDate(date : NSDate) -> Double {
        let JD_JAN_1_1970_0000GMT = 2440587.5
        return JD_JAN_1_1970_0000GMT + date.timeIntervalSince1970 / 86400
    }
    
    func dateFromJd(jd : Double) -> NSDate {
        let JD_JAN_1_1970_0000GMT = 2440587.5
        return  NSDate(timeIntervalSince1970: (jd - JD_JAN_1_1970_0000GMT) * 86400)
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
        self.locationManager.startUpdatingLocation()
    }
    
    func setupLocationManager(){
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager?.startUpdatingLocation()
        
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
        let locationValue:CLLocationCoordinate2D = manager.location!.coordinate
        
        //RA of Zenith Conversion Method From Longitude
        
        let locale = NSTimeZone.init(abbreviation: "UTC")
        NSTimeZone.default = locale as! TimeZone
        
        let gregorian = Calendar(identifier: .gregorian)
        let now = Date()
        var components = gregorian.dateComponents([.year, .month, .day, .hour, .minute, .second], from: now)
        
        components.hour = 0
        components.minute = 0
        components.second = 0
        
        let date0h = gregorian.date(from: components)!
        
        components.hour = 24
        
        let date0hJD = jdFromDate(date: date0h as NSDate)
        let nowJD = jdFromDate(date: now as NSDate)
        
        let D = nowJD - 2451545.0
        let D0 = date0hJD - 2451545.0
        
        let H = Double(gregorian.component(.hour, from: now))
        
        let GMST = 6.697374558 + (0.06570982441908 * D0) + (1.00273790935 * H) + (0.000026 * (D/36525) * (D/36525))
        
        let GAST = GMST + (((-0.000319 * sin(125.04 - (0.052954 * D))) - (0.000024 * sin(2 * (280.47 + (0.98565 * D))))) * cos(23.4393 - (0.0000004 * D)))
        
        ra = String(GAST.truncatingRemainder(dividingBy: 24) + (locationValue.longitude / 15))
        //ra = String(GMST.truncatingRemainder(dividingBy: 24) + (locationValue.longitude / 15)) //GMST seems to be closer to value from USNO but GAST is supposed to be the correct value
        dec = String(locationValue.latitude) //The declination at the zenith is equal to the site's latitude; therefore, the zenith for an observer at 45°N will be +45°.
        
        astroPicURL = URL(string: "https://skyserver.sdss.org/dr13/SkyServerWS/ImgCutout/getjpeg?ra=" + ra + "&dec=" + dec + "&scale=0.79224&width=" + screenWidth + "&height=" + screenHeight)
        
        do {
            data = try Data(contentsOf: astroPicURL)
            image = NSImage(data: data)
            print("Image fetched.")
            
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            
            let destinationURL = documentsURL.appendingPathComponent("EmpyreanEyesImage.png")
            
            if image.pngWrite(to: destinationURL) {
                print("File saved.")
            }
            
            do {
                try workspace.setDesktopImageURL(destinationURL, for: screen, options: [:])
                print("Desktop Changed.")
            } catch {
                print("--------------------")
                print("ALERT: Cannot change desktop image.")
                print("ERROR: ")
                print(error)
                print("--------------------")
                //Add some error stuff in statusbar window if cannot fetch image
            }

        } catch {
            print("--------------------")
            print("ALERT: Cannot get png from url: ")
            print(astroPicURL)
            print("ERROR: ")
            print(error)
            print("--------------------")
            //Add some error stuff in statusbar window if cannot fetch image
        }
        
        locationManager?.stopUpdatingLocation()
        manager.delegate = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print(error)
    }

}
