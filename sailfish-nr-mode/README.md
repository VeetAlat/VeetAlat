# NR Mode for Sailfish OS

A small Silica app that adds the **"NR only"** switch Android hides behind
`*#*#4636#*#*`. When it's on, the modem uses 5G NR standalone (SA) cells and
ignores LTE, 3G and 2G.

> ⚠️ In NR only mode the phone has **no service at all** outside 5G SA
> coverage. Calls and SMS only work if your operator supports VoNR, and
> emergency calls may not work. The app can revert automatically if no SA
> cell turns up in time (3 minutes by default; 1, 3, 5 minutes or never).

## How Sailfish handles LTE, NR and friends

Sailfish OS doesn't talk to the modem directly. The chain is:

```
Settings app / this app
        │  D-Bus: org.ofono.RadioSettings.TechnologyPreference
        ▼
ofono (Sailfish fork)          "any" | "gsm" | "umts" | "lte" | "nr"
        │
ofono-binder-plugin            maps the preference to an Android modem mode
        │  binder: setAllowedNetworkTypesBitmap / setPreferredNetworkTypeBitmap
        ▼
Android vendor radio HAL (IRadio / IRadioNetwork) → modem firmware
```

Things worth knowing:

- **TechnologyPreference is a ceiling, not a lock.** `lte` means
  "LTE, UMTS or GSM", and `nr` means "NR, LTE, UMTS or GSM". There's no value
  for "only this one". That's why the Sailfish settings page has no NR only
  option.
- In `ofono-binder-plugin` (`src/binder_network.c`,
  `binder_network_mode_to_pref()`), `nr` is **hardcoded** to
  `NR_LTE_GSM_WCDMA` (33).
- `lte`, though, is mapped to whatever integer the **`lteNetworkMode`** config
  key holds, with no validation. The plugin already knows
  `RADIO_PREF_NET_NR_ONLY = 23` and converts it into an NR-only access family
  bitmap for modern HALs (`binder_raf_from_pref()` in `src/binder_util.c`).
- Config comes from `/etc/ofono/binder.conf`, merged with drop-ins in
  `/etc/ofono/binder.d/*.conf`. Per-slot `[slotN]` keys override `[Settings]`.
- Changing radio settings over D-Bus needs the `sailfish-radio` or
  `privileged` group (ofono's `sailfish_access` plugin). Normal apps are
  read-only.
- Older devices that use `ofono-ril-plugin` (`ril_subscription.conf`)
  never list NR, but they still pass `lteNetworkMode` to the vendor RIL, so
  the same trick may work there if the modem supports it.

## The trick

1. Write `/etc/ofono/binder.d/90-nr-mode.conf` with `lteNetworkMode=23`
   (for `[Settings]` and every `[slotN]` group that already exists).
2. Restart ofono so it rereads the config.
3. Set `TechnologyPreference` to `lte` on each modem that lists `nr` in
   `AvailableTechnologies`. ofono now sends mode 23 (NR only) to the modem.

Phones that use the older `ofono-ril-plugin` work the same way: it has the
same `lteNetworkMode` key, read from `/etc/ofono/ril_subscription.conf` and
`ril_subscription.d/` with `[ril_N]` sections, and passes the value straight
to the vendor RIL. The helper detects which plugin is in use.

**"ofono doesn't list 5G" doesn't mean the modem can't do it.**
`AvailableTechnologies` is just the `technologies` value from the ofono
config. The binder plugin also hides NR when the radio HAL is older than 1.4,
and the RIL plugin never lists it. The helper therefore tries anyway and
logs why ofono didn't list NR. The modem firmware has the final say, and
auto-revert covers the case where it says no.

Turning it off deletes the drop-in, restarts ofono and restores the previous
preference (`nr` if it was anything odd). Side effect while it's on: the
stock Settings app shows "4G" as the preferred mode, because as far as ofono
knows, it is.

## Architecture

Only the helper runs as root, and it only accepts four exact words.

| Part | What it does |
|---|---|
| `qml/` | Silica UI. Live network, SIM and APN state via `QOfono`; per-cell signal via `Nemo.DBus` and ofono's `org.nemomobile.ofono.CellInfo`. |
| `src/nrcontrol.*` | Small C++ class. Writes `on` / `on-keep` / `off` / `diag` to `/run/nr-mode/request`, watches the state, log and diagnostics files. |
| `systemd/nr-mode-apply.path` | Starts the helper whenever the request file is written. |
| `helper/nr-mode-helper` | POSIX `sh` root helper: drop-in, ofono restart, `dbus-send`, auto-revert. |
| `systemd/tmpfiles.d/` | Creates `/run/nr-mode`, writable only by group `privileged`. |

The app binary is installed setgid `privileged` (like Jolla's own system apps)
so it can write the request file. That's why it's launched without a booster
and with `Sandboxing=Disabled`. It also means **it can't go in the Jolla
Store (Harbour)**. Ship it via OpenRepos or Chum instead.

## Monitoring and troubleshooting

In the app, pull down on the main page:

- **Monitor and log**: a live timeline of every change (registration,
  technology, serving cell with RSRP/RSRQ/SINR, data attach, APN bearer,
  number of visible 5G cells) plus the helper's step-by-step log.
- **Diagnostics report**: modem, SIM, network, radio settings, data contexts
  (APNs), every visible cell with signal values, the ofono config and
  ofono's own recent log. IMSI, ICCID and APN passwords are masked.

Both have a pull-down "Copy" item, handy for pasting into a bug report.

The same from Terminal (Developer mode):

```sh
H=/usr/libexec/nr-mode/nr-mode-helper
devel-su $H on 300      # switch on, printing every step; revert after 300 s
                        # without registration (default 60)
devel-su $H on-keep     # same, without auto-revert
devel-su $H off
devel-su $H diag        # full report (root lets it read ofono's journal)
$H watch                # live one-line status every 2 s, Ctrl+C to stop
cat /run/nr-mode/log    # everything the helper has done
```

What to look for when NR only doesn't connect:

- **`5G NR cells visible: 0`** (or no `nr` lines under "Cells the modem can
  see" in normal mode): the phone can't see any 5G here. No setting fixes
  that.
- **NR cells visible, but only while LTE is connected**: that's usually 5G
  **NSA**, which needs an LTE anchor. NR only mode needs **SA**, which
  many operators haven't launched or only enable for some subscriptions.
- **Right after a switch the modem is often still `searching`.** The
  report shows how long ofono has been running. A first 5G SA scan after a
  radio restart can take minutes, so check again after a while, or use
  `watch`.
- **A private or test network SIM** (unusual provider name, own MCC/MNC)
  only registers on that network. If it's SA-only, its band has to be
  supported and enabled in the modem firmware's operator profile.
- **`Error N setting pref mode`** in the ofono lines: the modem firmware
  rejected NR only (mode 23).
- **Registered but `Attached: false`**: the radio works, but data doesn't.
  Check the APN; some operators use a different APN or need provisioning
  for SA.

## Building

With Docker, no SDK install needed. This uses the community
`coderus/sailfishos-platform-sdk` image, which is about 4.5 GB:

```sh
cd sailfish-nr-mode
./build-rpm.sh aarch64      # or armv7hl for older 32-bit phones
```

It builds against Sailfish OS 4.6, so the package also runs on 5.x. The RPM
lands in `RPMS/`. With the official SDK installed instead, use
`sfdk config target=SailfishOS-4.6.0.13-aarch64 && sfdk build`.

## Installing

Needs Developer mode (Settings → Developer tools). Copy the RPM to the phone,
then in Terminal:

```sh
devel-su pkcon install-local ~/Downloads/nr-mode-0.4.0-1.aarch64.rpm
```

If `pkcon` refuses the unsigned package, use
`devel-su rpm -i ~/Downloads/nr-mode-0.4.0-1.aarch64.rpm` instead.

## Tests

These run on a normal Linux box, no phone needed:

```sh
# Helper against a fake ofono on a private D-Bus
# (needs dbus-daemon and python3 with dbus-python + PyGObject)
tests/test-helper.sh

# NrControl unit tests (Qt 5)
cd tests/nrcontrol && qmake && make && ./tst_nrcontrol
```

## Lightweight app building blocks on Sailfish

These are on every Sailfish phone already, so using them costs your RPM
nothing:

| Package | QML import / API | Use it for |
|---|---|---|
| `sailfishsilica-qt5` | `Sailfish.Silica 1.0` | Native UI components (pages, pulley menus, switches, covers) |
| `libsailfishapp` | `SailfishApp::` (C++) | Tiny `main.cpp` boilerplate, QML paths, icons |
| `libqofono-qt5-declarative` | `QOfono 0.2` | Modem, SIM, network registration, radio settings |
| `nemo-qml-plugin-dbus-qt5` | `Nemo.DBus 2.0` | Calling any D-Bus service straight from QML |
| `nemo-qml-plugin-configuration-qt5` | `Nemo.Configuration 1.0` | Persisting small settings (dconf) |
| `nemo-qml-plugin-notifications-qt5` | `Nemo.Notifications 1.0` | System notifications |
| `qt5-qtdeclarative` | `QtQuick 2` | Everything else |

A pure QML app can even skip C++ and run under `sailfish-qml`. This one needs
a little C++ only because QML can't write files.

## Ideas for later

- A per-SIM option instead of switching every NR-capable modem.
- Upstream a proper `nrNetworkMode` key (or an `nr-only` preference) to
  `ofono-binder-plugin`, which would remove the need for the `lte` trick.
