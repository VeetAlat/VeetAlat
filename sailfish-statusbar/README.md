# StatusBar: a Patchmanager patch for Sailfish OS

On phones with a notch (like the 2026 Jolla Phone), Sailfish apps run
right up to the top of the screen, and the time and battery only show on
the home screen. Android apps get a black bar over the notch instead.

**StatusBar** gives native apps the same: while an app is open with the
phone upright, a black bar as tall as the notch covers it. The bar shows
the time beside the notch, and the home screen's own status icons
(battery, profile, Bluetooth, Wi-Fi, mobile signal, dual SIM).

Made by Valatalo.

## How it works

- **`patch/unified_diff.patch`** adds a `Loader` to the home screen's
  `layers/AppLayer.qml`. Nothing else in the system changes. The Loader
  sits in the app layer's overlay: above the app, moving with it when you
  swipe to peek at the home screen.
- **`qml/NotchStatusBar.qml`** is the bar, installed in the package's
  own folder (`/usr/share/sailfishos-patch-statusbar/`). It reuses
  Lipstick's `StatusArea` and `ClockItem`, so it shows exactly what the
  home screen shows, and sizes itself from `Screen.topCutout`.
- **Safe by design:** the bar is loaded from its own file, so if it ever
  fails on some Sailfish version, apps keep working; there's just no bar.
  A wrong change inside `AppLayer.qml` itself could stop apps from
  opening, so that change is kept to the Loader alone.
- **Upright only.** Turned sideways, the notch is at the side and apps
  get the whole screen as before.
- **What it covers:** Silica apps already keep that strip clear (they pad
  for `Screen.topCutout`), so there the bar covers only padding.
  Full-screen apps like games and video lose that strip, as Android apps
  do.

## Installing

1. Install **Patchmanager** (from Chum or OpenRepos).
2. Install the package:
   `devel-su pkcon install-local sailfishos-patch-statusbar-0.1.0-1.noarch.rpm`
3. Settings → Patchmanager → **StatusBar** → Apply, then restart the home
   screen (Patchmanager offers to).

Uninstalling the package takes the patch off first.

## Checked so far

- **The diff** applies to Sailfish OS 4.6's `AppLayer.qml` and gives
  exactly the intended file.
- **The patched `AppLayer.qml` and the bar compile against the real
  Sailfish modules in the SDK.** The SDK lacks only the home screen's
  private plugin, so a stand-in replaces it. The only remaining error
  comes from inside Jolla's own `StatusArea` (its `NetworkTrafficMonitor`
  lives in that plugin), and the stock file shows it too.
- **Not yet checked:** the 2026 Jolla Phone runs Sailfish 5.2, and the
  diff has to match its `AppLayer.qml` exactly. If Patchmanager says the
  patch doesn't apply, that file differs and the diff needs rebasing.
- **Not yet seen:** how it looks on the phone.

## Made with AI-assisted tools

This patch has been created using AI generated code (Claude code).
