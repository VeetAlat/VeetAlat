# VeetPatched

Small changes to Sailfish OS's own software, each with an on/off switch:
an app of its own, instead of Patchmanager.

Made by Valatalo.

## Patches

- **StatusBar:** while an app is open with the phone upright, a black
  bar as tall as the notch covers it, with the time beside the notch and
  the home screen's own status icons (battery, profile, Bluetooth, Wi-Fi,
  mobile signal). It slides with the app when you peek at the home
  screen. Silica apps already keep that strip clear; full-screen apps
  lose it, as Android apps do.

## How StatusBar fits around the notch

- **Left of the notch is StatusBar's own:** the clock at the left edge,
  like Android, then a compact battery. If they don't fit before the
  notch, they shrink just enough to fit, to 60% at most.
- **Right of the notch:** the home screen's own status icons (location,
  VPN, Bluetooth, Wi-Fi, mobile signal), seen through a window cut to
  that side. Its left icons (its battery and percentage, profile, do not
  disturb, alarm) are left out that way, without depending on how a
  Sailfish version builds them. On Sailfish 4.6 the right icons also
  shrink if they'd reach the notch.
- **The compact battery** shows the charge percentage inside a small
  battery: under half the width of the home screen's icon with the
  percentage beside it. The fill shows the charge, green while charging,
  red when low and amber in power save.
- **Where its numbers come from:** the first of these that works on the
  phone: MCE, the power manager (`BatteryFromMce.qml`); a hidden copy of
  Sailfish's own battery indicator (`BatteryFromIndicator.qml`); the
  system settings' battery status (`BatteryFromSettings.qml`). A file
  that doesn't load, or gives no charge within 4 s, is skipped. If none
  works, the bar shows the home screen's whole status area, its battery
  included, as before.
- **Its report:** 8 s after the home screen starts, StatusBar reports the
  notch, which battery source it uses (and which it tried), and the room
  on each side. VeetPatched's Log page shows it the next time the app
  checks.

## Restarting the home screen

Changes to the home screen only show after it restarts. The app offers
it after switching a patch, and also whenever the helper finds that the
home screen started before the patches last changed (after updating
VeetPatched, for example). It's always in the pull-down menu too.
Right of it: the right icons (location, VPN, Bluetooth, Wi-Fi, mobile
signal) at the right edge. If one side doesn't fit next to the notch, it
shrinks just enough to fit, to 60% at most. Three seconds after the
home screen starts, it reports how it fitted (the notch, the room on each
side, how much it shrank, and which battery it shows); VeetPatched's Log
page shows it the next time the app checks.

## How it works

- **The app** (sandboxed, no permissions) can't change system files.
  Flipping a switch writes one line, like `apply statusbar 17`, to
  `~/.local/share/org.veetalat/veetpatched/request`.
- **The watcher:** `veetpatched.path` (systemd) watches that file and
  starts `veetpatched.service`. That runs the root helper,
  `/usr/libexec/veetpatched/veetpatched-helper serve`.
- **The helper** only accepts the patches that ship in
  `/usr/share/veetpatched/patches`. It refuses anything else, and a
  request that's a symlink. It writes its answer (`status`, `log`) back
  as the user, so root never writes into a folder the user controls.
- **What a patch is:** `patch.conf` (the file, a line it must contain, a
  block) and the block itself. The helper puts the block in just before
  the file's last closing brace, between `VEETPATCHED:ID:begin`/`end`
  comments. That's more forgiving than a diff: whitespace or a missing
  final newline don't matter.
- **Taking a patch out** removes exactly those lines, and the original
  (backed up in `/var/lib/veetpatched/backup`) comes back byte for byte.
- **Safe failure:** StatusBar's block is only a `Loader` for its own file
  (`/usr/share/veetpatched/patches/statusbar/NotchStatusBar.qml`). If the
  bar fails, apps still work, just without it.
- **When it starts:** the watcher starts with the user's session
  (`user@100000.service`), so `/home` is mounted (it can be encrypted)
  before it watches.

**Before updating Sailfish OS, switch the patches off.** An update
replaces the changed files, which simply removes the patch.

## Logging

Both halves keep a log, and the app shows them merged, in time order:
pull down → **Log**.

- **Every line** has a time, a level (`INFO`, `WARN` or `ERROR`) and
  where it came from: **helper (root)** or **app**.
- **The helper** logs each request and its answer, plus the phone it ran
  on (Sailfish version, the home screen package, its own version). For
  each step of a patch it logs the file's size and sha256 before and
  after, the backup, the line the block goes in before, and the check
  that taking it out again gives the original.
- **Failures say why:** a command's exit code and its error output, the
  file that wasn't as expected, or that the home screen couldn't be
  restarted and why.
- **Rejected requests** are logged without their contents.
- **The app** logs starting up, every request it sends, and how long
  the answer took. If no answer comes, it logs an ERROR saying the
  helper isn't running.
- **Problems only** (pull-down on the Log page) shows only the warnings
  and errors. **Copy log** copies everything as text, ready to paste
  somewhere.
- **The full log** is in `/var/lib/veetpatched/log` (rotated at 256 KB).
  The helper also logs to the system journal:

  ```sh
  devel-su journalctl -t veetpatched
  ```

- **The home screen's own lines** about the patches (StatusBar's report,
  QML errors in its files) are copied from the journal into the log, each
  once, when the app checks.
- **The app's own log** is `app.log` in
  `~/.local/share/org.veetalat/veetpatched/` (rotated at 128 KB).

## If something goes wrong

In the Terminal:

```sh
devel-su /usr/libexec/veetpatched/veetpatched-helper unapply-all
```

then restart the phone. Uninstalling VeetPatched does the same first.

## Building

```sh
./build-rpm.sh aarch64      # Docker; RPM lands in RPMS/
devel-su pkcon install-local ~/Downloads/veetpatched-0.3.0-1.aarch64.rpm
```

## Tests

```sh
sh tests/test_helper.sh       # the helper: 89 checks
tests/sdk-smoke-test.sh       # the app and the real helper together, in the SDK: 30 checks
tests/bar-layout-test.sh      # StatusBar's layout, battery and its sources, in the SDK
```

**The helper's tests:**
- apply and remove on Sailfish 4.6's `AppLayer.qml` and 5.2's layout
  (from the phone), on a file with no final newline, and with CRLF line
  ends;
- the original comes back byte for byte, and doing anything twice
  changes nothing;
- a wrong or missing file is left alone, and unknown or malicious
  requests are refused;
- after an OS update, taking a patch out keeps the update;
- the log has every step with levels and checksums, refused requests
  are logged without their contents, and the log rotates.

They pass on GNU tools, on the SDK target's own tools and on BusyBox.

**The smoke test** runs the app in the SDK with the real helper in a loop
standing in for systemd. It taps StatusBar's switch on and off through
the page, and checks the home screen file is the original afterwards.
It also checks both logs: the app's requests and answer times, the
helper's steps, the failed home screen restart and a helper that never
answers as ERRORs, and the Log page's *Problems only* filter.
The patched file and the bar also compile against the SDK's Sailfish
modules, with a stand-in for the home screen's private plugin.

**The layout test** lays out the real bar file in the SDK over five notch
shapes, from a small punch hole to a very wide notch, with a stand-in
for the home screen's status area built like the real one. It checks:

- the clock and the battery never overlap each other or the notch, and
  only shrink when they have to;
- the home screen's left icons are hidden and its right icons show,
  clear of the notch;
- the battery's number and colours follow its source;
- a source that doesn't load, or gives no charge, is skipped for the
  next, and with none the home screen's whole status area shows;
- the three real sources load;
- the report line.

**Not testable here:** systemd running the helper on the phone (the units
pass `systemd-analyze verify`), and the bar on the real screen.

## Made with AI-assisted tools

This app has been created using AI generated code (Claude code).
