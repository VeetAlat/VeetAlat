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

## If something goes wrong

In the Terminal:

```sh
devel-su /usr/libexec/veetpatched/veetpatched-helper unapply-all
```

then restart the phone. Uninstalling VeetPatched does the same first.

## Building

```sh
./build-rpm.sh aarch64      # Docker; RPM lands in RPMS/
devel-su pkcon install-local ~/Downloads/veetpatched-0.1.0-1.aarch64.rpm
```

## Tests

```sh
sh tests/test_helper.sh       # the helper: 56 checks
tests/sdk-smoke-test.sh       # the app and the real helper together, in the SDK: 19 checks
```

**The helper's tests:**
- apply and remove on Sailfish 4.6's `AppLayer.qml` and 5.2's layout
  (from the phone), on a file with no final newline, and with CRLF line
  ends;
- the original comes back byte for byte, and doing anything twice
  changes nothing;
- a wrong or missing file is left alone, and unknown or malicious
  requests are refused;
- after an OS update, taking a patch out keeps the update.

They pass on GNU tools, on the SDK target's own tools and on BusyBox.

**The smoke test** runs the app in the SDK with the real helper in a loop
standing in for systemd. It taps StatusBar's switch on and off through
the page, and checks the home screen file is the original afterwards.
The patched file and the bar also compile against the SDK's Sailfish
modules, with a stand-in for the home screen's private plugin.

**Not testable here:** systemd running the helper on the phone (the units
pass `systemd-analyze verify`), and the bar on the real screen.

## Made with AI-assisted tools

This app has been created using AI generated code (Claude code).
