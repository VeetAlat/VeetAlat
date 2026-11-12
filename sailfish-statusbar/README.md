# StatusBar: a Patchmanager patch for Sailfish OS

On phones with a notch (like the 2026 Jolla Phone), Sailfish apps run
right up to the top of the screen, and the time and battery only show on
the home screen. Android apps get a black bar over the notch instead.

**StatusBar** gives native apps the same: while an app is open with the
phone upright, a black bar as tall as the notch covers it. Left of the
notch: the time and a compact battery (the percentage inside a small
battery; green while charging, red when low, amber in power save). Right
of it: the home screen's own status icons (Bluetooth, Wi-Fi, mobile
signal, location, VPN).

It's the bar from [VeetPatched](../sailfish-veetpatched), where it was
developed and tested on the 2026 Jolla Phone, packaged for Patchmanager.

Made by Valatalo.

## How it works

- **`patch/unified_diff.patch`** adds a `Loader` at the end of the home
  screen's `layers/AppLayer.qml`. Nothing else in the system changes. The
  Loader sits in the app layer's overlay: above the app, moving with it
  when you swipe to peek at the home screen. The diff only needs the
  file's last two lines (`    }` and `}`) to match, so it applies to
  Sailfish 4.6 and 5.2 alike.
- **The bar** is in the package's own folder,
  `/usr/share/sailfishos-patch-statusbar/`:
  - `NotchStatusBar.qml`: the bar. Left of the notch, its own clock and
    battery, shrunk to fit if needed. Right of it, the home screen's
    `StatusArea` seen through a window cut to that side, which leaves out
    the home screen's own battery however a Sailfish version builds it.
  - `CompactBattery.qml`: the battery.
  - `BatteryFromMce.qml`, `BatteryFromIndicator.qml`,
    `BatteryFromSettings.qml`: where the battery's numbers come from, the
    first that works on the phone. With none, the home screen's whole
    status area shows, its battery included.
- **Safe by design:** the bar is loaded from its own file, so if it ever
  fails on some Sailfish version, apps keep working; there's just no bar.
- **Upright only.** Turned sideways, the notch is at the side and apps
  get the whole screen as before.
- **What it covers:** Silica apps already keep that strip clear (they pad
  for `Screen.topCutout`), so there the bar covers only padding.
  Full-screen apps like games and video lose that strip, as Android apps
  do.

## Installing

1. **If you use VeetPatched's StatusBar, switch it off there first** and
   restart the home screen; with both, you'd get two bars.
2. Install **Patchmanager** (from Chum or OpenRepos).
3. Install the package:
   `devel-su pkcon install-local sailfishos-patch-statusbar-0.2.0-1.noarch.rpm`
4. Settings → Patchmanager → **StatusBar** → Apply, then restart the home
   screen (Patchmanager offers to).

Uninstalling the package takes the patch off first.

## Tests

```sh
sh tests/test_patch.sh      # the diff, the way Patchmanager uses it: 29 checks
```

On copies of `AppLayer.qml` from Sailfish 4.6 and from the phone (5.2):

- Patchmanager's own checks: the patch isn't taken as already applied,
  and the dry run passes;
- it applies with exact matches only (no fuzz), and on the phone's file
  right where the diff says;
- the Loader goes in once, at the end of the app layer;
- taking it off gives the original back, byte for byte.

It also checks that the bar's files are the same as VeetPatched's (whose
tests lay the bar out in the SDK and check its battery sources), and
that the package installs them all.

## Made with AI-assisted tools

This patch has been created using AI generated code (Claude code).
