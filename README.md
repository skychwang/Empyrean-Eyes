# Empyrean Eyes

Your desktop wallpaper, set to the patch of sky directly above you — and kept
there as the Earth turns. A small menu bar app for macOS, inspired by
[Satellite Eyes](https://github.com/tomtaylor/satellite-eyes).

## Install

Download `EmpyreanEyes.zip` from
[Releases](https://github.com/skychwang/Empyrean-Eyes/releases), unzip it, and
drag `EmpyreanEyes.app` to `/Applications`.

The app is signed ad-hoc rather than with a paid Developer ID, so Gatekeeper
will not open it on the first double-click. Either right-click the app and
choose **Open**, or clear the quarantine flag:

```sh
xattr -dr com.apple.quarantine /Applications/EmpyreanEyes.app
```

On first run, macOS asks for Location Services access. If you would rather not
grant it, open **Preferences** from the menu bar and enter a latitude and
longitude by hand.

Requires macOS 13 Ventura or later. Universal — Apple silicon and Intel.

## How it works

Local sidereal time *is* the right ascension of your meridian, and the zenith
sits on the meridian by definition. So the app takes your latitude and
longitude, computes Greenwich Apparent Sidereal Time using the
[USNO's formulae](https://aa.usno.navy.mil/faq/GAST), and converts to local
sidereal time — which gives the right ascension overhead. Declination at the
zenith is simply your latitude.

Those coordinates go to the Sloan Digital Sky Survey's
[SkyServer image cutout service](https://skyserver.sdss.org/dr19/), which
returns a real telescope image of that patch of sky at your display's exact
pixel dimensions. That becomes your wallpaper, on every attached display,
refreshed on an interval you choose.

## Preferences

| Setting | What it does |
| --- | --- |
| Refresh interval | How often to re-aim and re-fetch. Default 30 minutes. |
| Arcsec / pixel | Field of view. Lower zooms in; higher takes in more sky. |
| Data release | Which SDSS release to pull from. Default DR19. |
| Manual location | Skip Location Services and name a spot yourself. |

**Launch at Login** is a toggle in the menu itself.

## Coverage

SDSS imaged roughly a third of the sky, concentrated well away from the plane
of the Milky Way. When the zenith drifts outside that footprint, SkyServer
returns a blank frame. Rather than hang a black rectangle on your desktop,
Empyrean Eyes detects the blank tile, leaves your current wallpaper alone, and
says so in the menu. Wait a few hours and the sky rotates back into coverage.

## Building

```sh
git clone https://github.com/skychwang/Empyrean-Eyes.git
cd Empyrean-Eyes
xcodebuild -scheme EmpyreanEyes -configuration Release build
xcodebuild -scheme EmpyreanEyes test
```

Xcode 26 or later, Swift 6. The project signs ad-hoc by default, so it builds
with no Apple Developer account and no team configured.

## Screenshots

The menu, showing the coordinates currently overhead:

![Menu bar menu](images/1.png?raw=true "Menu bar menu")

Preferences:

![Preferences](images/2.png?raw=true "Preferences")

And the wallpaper it produced — the zenith over New York, from SDSS DR19:

![Fetched sky](images/3.jpg?raw=true "Fetched sky")

## Acknowledgements

Menu bar icon by [Freepik](https://www.flaticon.com/authors/freepik). Imagery
courtesy of the [Sloan Digital Sky Survey](https://www.sdss.org/).

## License

MIT — see [LICENSE](LICENSE).
