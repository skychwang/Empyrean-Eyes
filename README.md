# Empyrean Eyes

Set the views of the stars above you as your dynamic desktop wallpaper with Empyrean Eyes: a small, lightweight, navbar-centric OS X application inspired by [Satellite Eyes](https://github.com/tomtaylor/satellite-eyes). 

## Building / Running

Empyrean Eyes is XCode 8.2.1 Compatible and targets 10.12 (Mac OS X Sierra) upwards.  
To download an .app file of the project, navigate to Github releases and download the latest version.  

## Description of Functionality 

A native OS X app written in Swift 3 and built with XCode. Utilizes location services and the calculation featured at the [USNO](http://aa.usno.navy.mil/faq/docs/GAST.php) to compute the Right Ascension (RA) and Declination (DEC) of the zenith at current user location. This is then fed into the Sloan Digital Sky Survey's [DR13 Finding Chart Tool](http://skyserver.sdss.org/dr13/en/tools/chart/chartinfo.aspx) to return the image of the stars above you at your desktop wallpaper's dimensions, which is then used to set the desktop wallpaper. Wallpaper updates are periodic. 

## Screenshots  

![Taskbar Menu](images/1.png?raw=true "Taskbar Menu")
![Preferences](images/2.png?raw=true "Preferences")
![Fetched Image](images/3.png?raw=true "Fetched Image")

## Known Issue(s)

Users at certain locations may experience perodic outages in sky survey images, as the RA's (changes with time) corresponding DEC (fixed to the longitude of the user's position) at zenith may be out of the SDSS's recorded range.

## Acknowledgements

Icon is made by [Freepik](http://www.flaticon.com/authors/freepik).

## Features Yet To Be Implemented

Option to start on login  
Multiple sources and spectra  
...suggestions and direct feature contributions are welcome. 
