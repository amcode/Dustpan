# Dustpan

Sweeps menu bar icons out of sight. Nothing else.

- ⌘-drag any menu bar icon to the left of Dustpan's divider and it's hidden.
- Click the chevron to show them again; they sweep away automatically after a few seconds (or stay until you click).
- A keyboard shortcut to toggle, if you want one.
- No permissions, no Accessibility, no screen recording, no network. ~300 lines of Swift you can read in ten minutes.

Requires macOS 13 Ventura or later.

## Install

Grab `Dustpan-x.y.z.dmg` from the [latest release](https://github.com/amcode/Dustpan/releases/latest), drag **Dustpan** to Applications and open it. Two things appear in your menu bar: a thin divider and a chevron.

Hold ⌘ and drag the icons you don't want to see to the **left** of the divider. Click the chevron. Gone.

## Using it

| Action | Does |
|---|---|
| Click the chevron | Show / sweep the hidden icons |
| Click the divider | Sweep |
| ⌃ ⌥ H | Toggle (changeable, or turn it off) |
| Right-click either | Preferences |

Preferences: sweep away automatically after 3 s – 1 min (or not at all), sweep at launch, shortcut, launch at login.

## How it works

macOS lays menu bar icons out from the right and lets you reorder them with ⌘-drag. Dustpan adds two status items: a chevron on the right and a divider to its left. When you sweep, the divider's width is set to 10,000 points, which shoves everything on its left off the edge of the screen. Showing sets it back to a thin line. That's the entire trick; the same one the well-known open-source menu bar hiders use.

Because the icons are merely pushed off-screen, the apps behind them keep running normally. Icons to the *right* of the divider, including the system ones, are never touched.

### Known limitations

- On MacBooks with a notch, macOS itself already hides icons that don't fit. Dustpan still works, but space is tighter.
- If you ever ⌘-drag the divider to the right of the chevron, nothing can be hidden. Dustpan puts them back in order on next launch; or just drag the divider back.
- Apps that insist on recreating their status item at a fixed position can occasionally pop back to the visible side. Drag them left again.

## Build from source

```bash
git clone https://github.com/amcode/Dustpan.git
cd Dustpan
./build.sh          # runs the tests, then builds dist/Dustpan.app (universal)
```

Needs the Xcode Command Line Tools (`xcode-select --install`). You can also open `Package.swift` in Xcode.

## Tests

```bash
swift test
```

`DustpanCore` is a plain Swift library: the sweep/show state machine with its auto-sweep countdown, settings persistence, the hot key model and the menu bar presentation are all unit-tested with a hand-advanced clock.

## Releasing

```bash
git tag v1.0.0
git push origin v1.0.0
```

The `Release` workflow runs on GitHub's macOS runners: tests, universal build with the tag stamped into `Info.plist`, then a `.dmg`, `.zip` and `SHA256SUMS.txt` attached to the GitHub release.

### Signing and notarisation

Without secrets the build is ad-hoc signed and users see a Gatekeeper warning on first open. With a paid Apple Developer account, add these repository secrets and the next release is signed, notarised and stapled automatically:

| Secret | Value |
|---|---|
| `MACOS_CERTIFICATE_P12` | `base64 -i cert.p12 \| pbcopy` — your Developer ID Application cert + key |
| `MACOS_CERTIFICATE_PWD` | the .p12 export password |
| `APPLE_ID` | your Apple ID email |
| `APPLE_TEAM_ID` | 10-character team ID |
| `APPLE_APP_PASSWORD` | an app-specific password from appleid.apple.com |

## Website

The one-page site in `docs/` is published with GitHub Pages (Settings → Pages → Deploy from a branch → `main`, folder `/docs`). The download button reads the latest release from the GitHub API, so it updates itself when you tag a new version.

## Project layout

```
Package.swift
Sources/
  DustpanCore/         pure logic (tested)
    Sweeper.swift
    Settings.swift       (incl. HotKey)
    MenuBarPresenter.swift
    Scheduling.swift
  Dustpan/             the app (AppKit + Carbon wiring)
    main.swift
    AppDelegate.swift
    HotKeyRegistrar.swift
Tests/DustpanCoreTests/
docs/                  the website
Info.plist · Dustpan.entitlements · AppIcon.iconset/ · build.sh
.github/workflows/{ci,release}.yml
```

## Licence

MIT — see [LICENSE](LICENSE).
