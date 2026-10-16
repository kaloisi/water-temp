# Water Temp for iOS & macOS

A native SwiftUI app plus a WidgetKit widget that shows the current temperature
from one or more Weather Underground personal weather stations (PWS).

- **Widget** — small, medium and large widgets on the iOS/iPadOS Home Screen and
  the macOS desktop / Notification Center, plus Lock Screen widgets
  (rectangular and inline) on iOS. Refreshes about every 15 minutes.
- **Tap a station** to open its Weather Underground page
  (`https://www.wunderground.com/dashboard/pws/<ID>`) in your browser.
- **Add / remove stations** in two ways:
  - In the **Water Temp app**: type a station ID to add it (it's checked against
    the weather service first), swipe or right-click to remove, drag to reorder.
    Every widget that isn't customized shows this list.
  - Per widget, via **Edit Widget** (long-press on iOS, right-click on macOS):
    add or remove entries under *Station IDs*. Leave it empty to follow the
    app's list.

## Requirements

- Xcode 16 or later
- iOS / iPadOS 17+ or macOS 14+

## Running it

1. Open `apple/WaterTemp.xcodeproj` in Xcode.
2. For **both** targets (`WaterTemp` and `WaterTempWidgetExtension`), open
   *Signing & Capabilities* and pick your **Team**. If the bundle IDs
   `com.kaloisi.WaterTemp` / `com.kaloisi.WaterTemp.Widget` are taken by
   another team, change the prefix on both.
3. The app and widget share the station list through the App Group
   `group.com.kaloisi.watertemp`. If you change it, update it in
   `Config/*.entitlements` and `Shared/StationStore.swift`.
4. Choose the `WaterTemp` scheme and a destination (an iPhone simulator,
   a device, or *My Mac*), then Run.
5. Add the widget: on iOS long-press the Home Screen → **+** → *Water Temp*;
   on macOS right-click the desktop → *Edit Widgets…* → *Water Temp*.

## How it works

| Path | Contents |
| --- | --- |
| `Shared/` | Code compiled into both targets: the `Station` model, the App Group–backed `StationStore`, `WeatherService` (calls `api.weather.com` directly — no CORS proxy needed natively), and `DeepLink`. |
| `WaterTemp/` | The SwiftUI app: station list, add/remove, and the URL handler. |
| `WaterTempWidget/` | The widget extension: `ConfigurationAppIntent` (per-widget station IDs), the timeline provider, and the views. |
| `Config/` | Entitlements and Info.plist additions for each target. |

Widget taps launch the containing app with a `watertemp://station/<ID>` URL, and
the app immediately opens the station's Weather Underground page in the default
browser. Small widgets support only a single tap target, so a small widget with
one station opens that station; with several it opens the app's list, where
each station is tappable. Medium and large widgets make every row its own link.

The project uses Xcode 16 folder-synchronized groups, so any Swift file you add
under `Shared/`, `WaterTemp/` or `WaterTempWidget/` is picked up automatically.
