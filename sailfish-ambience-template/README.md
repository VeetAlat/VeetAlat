# Sailfish OS ambience template

A ready-to-fill template for making a Sailfish OS **ambience**: a wallpaper,
a highlight colour and (optionally) your own ringtone and notification sounds,
packaged as an RPM you can upload to OpenRepos.

## What's inside

```
sailfish-ambience-template/
├── ambience-myname.spec           # RPM recipe (name, version, description)
├── build.sh                       # builds the .rpm
└── ambience/
    ├── ambience-myname.ambience   # JSON: name, wallpaper, colour, sounds
    ├── images/                    # put your wallpaper .jpg here
    └── sounds/                    # put your .ogg sounds here (optional)
```

On the phone it installs to `/usr/share/ambience/ambience-myname/`, where
`ambienced` finds it and it shows up in Settings → Ambiences.

## Make your own

1. **Pick a name**, e.g. `ambience-northernlights`. Rename
   `ambience-myname.spec` and `ambience/ambience-myname.ambience` to it, and
   replace every `ambience-myname` inside both files.
2. **Add the wallpaper**: a `.jpg` in `ambience/images/`, named to match
   `"wallpaper"` in the `.ambience` file. Use at least your phone's screen
   resolution; a square-ish image around 2000–2500 px works well because
   Sailfish lets people crop/scroll it.
3. **Pick a colour**: `"highlightColor"` is the accent colour (e.g. `#8bd4ff`).
4. **Sounds (optional)**: drop `.ogg` files into `ambience/sounds/` and point
   the `*ToneFile` entries at them. Any sound you don't want to change: delete
   that whole entry from the JSON so the user's existing sound stays. Using
   no custom sounds at all? Delete all seven entries.
5. **Edit the spec**: version, summary, description, license, changelog.
6. **Build**: `./build.sh` (needs `rpmbuild` – `sudo apt install rpm` on
   Debian/Ubuntu, `dnf install rpm-build` on Fedora). The package lands in
   `RPMS/noarch/`. It's `noarch`, so the same file works on every Sailfish
   phone (ARM, aarch64, x86).
7. **Test**: copy the .rpm to the phone and run
   `devel-su pkcon install-local ambience-*.rpm` in Terminal, or tap it in
   the file manager (with "allow untrusted software" enabled).
8. **Release**: upload the .rpm to openrepos.net as a new app in the
   *Ambiences* category, with a screenshot or two.

### Sound entries

| Key                    | Used for                  |
|------------------------|---------------------------|
| `ringerToneFile`       | Incoming calls            |
| `messageToneFile`      | SMS                       |
| `chatToneFile`         | Instant messages          |
| `mailToneFile`         | Email                     |
| `internetCallToneFile` | VoIP calls                |
| `calendarToneFile`     | Calendar reminders        |
| `clockAlarmToneFile`   | Alarms                    |

Ogg Vorbis is the safest format. Keep notification sounds short (1–3 s) and
normalise volumes so your ringtone doesn't scare anyone.
