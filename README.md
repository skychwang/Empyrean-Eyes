# Empyrean Eyes

Empyrean Eyes is a small OS X application that automatically updates your desktop wallpaper to the view of the cosmos directly atop your current position.

Inspired by [Satellite Eyes](https://github.com/tomtaylor/satellite-eyes).

## Current State of Project

Status bar app UI ✓  
Quit button ✓  
Update button and function ✓  
Preferences button and window ✓  
Update and persist auto-update/fetch interval from preferences window ✓  
Image scaling ✓  
Implement auto-update async loop ✓  
In-menu unintrusive error messages ✓  
Option to start on login  
Multiple sources and spectra  
...more features to come in the future.  

## Building / Running

Empyrean Eyes is XCode 8.2.1 Compatible and targets 10.12 (Mac OS X Sierra) upwards.  
To download an .app file of the project, navigate to Github releases and download the latest version.  

## How I built it

Native OS X app written in Swift 3 and built with XCode. Utilizes location services and the calculation featured at the [USNO](http://aa.usno.navy.mil/faq/docs/GAST.php) to compute the Right Ascension and Declination of the zenith at current user location, which is fed into the Sloan Digital Sky Survey's [DR13 Finding Chart Tool](http://skyserver.sdss.org/dr13/en/tools/chart/chartinfo.aspx) to return the image at the correct dimensions then used to set the desktop wallpaper.

## Screenshots  

![Taskbar Menu](images/1.png?raw=true "Taskbar Menu")
![Preferences](images/2.png?raw=true "Preferences")
![Fetched Image](images/3.png?raw=true "Fetched Image")

## Known Issue(s)

Users at certain locations may experience perodic outages in sky survey images as the RA's (changes with time) corresponding DEC (fixed to the longitude of the user's position) at zenith may be out of the SDSS's recorded range.

## Acknowledgements

Icon made by [Freepik](http://www.flaticon.com/authors/freepik).

## etc.

First time developing for Mac OS X using Swift. StackOverflow was really helpful for syntax.
