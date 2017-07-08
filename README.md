# Empyrean Eyes

Empyrean Eyes is a small OS X application that automatically updates your desktop wallpaper to the view of the cosmos directly atop your current position.

Inspired by [Satellite Eyes](https://github.com/tomtaylor/satellite-eyes).

## Current State of Project

Status bar app UI ✓  
Quit button ✓  
Update button and function ✓  
Preferences button and window ✓  
Update and persist auto-update/fetch interval from preferences window ✓  
Implement auto-update async loop  
In-menu unintrusive error messages  
...more to come.  

## Building

Empyrean Eyes is XCode 8.2.1 Compatible and targets 10.12 (Mac OS X Sierra) upwards.

## How I built it

Native OS X app written in Swift 3 and built with XCode. Utilizes location services and the calculation featured at the [USNO](http://aa.usno.navy.mil/faq/docs/GAST.php) to compute the Right Ascension and Declination of the zenith at current user location, which is fed into the Sloan Digital Sky Survey's [DR13 Finding Chart Tool](http://skyserver.sdss.org/dr13/en/tools/chart/chartinfo.aspx) to return the image at the correct dimensions then used to set the desktop wallpaper.

## Known Issue(s)

Users at certain locations may experience perodic outages in sky survey images as the RA's (changes with time) corresponding DEC (fixed to the longitude of the user's position) at zenith may be out of the SDSS's recorded range.

## Acknowledgements

Icon made by [Freepik](http://www.flaticon.com/authors/freepik).

## etc.

First time developing for Mac OS X using Swift. StackOverflow was really helpful for syntax.
