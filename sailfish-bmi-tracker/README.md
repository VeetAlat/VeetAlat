# BMI Tracker for Sailfish OS

A native Silica app for logging your weight and following your body mass
index over time.

- A first-run guide explains the three steps, with a button for each.
- Enter your **height** (cm or feet and inches), **age** and **gender** once,
  using simple tap-to-choose buttons and step-by-step instructions.
- Log your **weight** in kilograms or pounds, with a date.
- See your BMI on a **blue / green / yellow / red** scale (underweight /
  normal / overweight / obese), your normal weight range for your height,
  and a **history chart** with the same colour bands. Tap or drag across
  the chart to see a measurement.
- Everything is **saved on the phone** and is there again the next time you
  open the app.
- The cover shows your latest BMI, and its **+** button opens "Add weight".
- **About and disclaimers** in the pull-down menu: not medical advice, made
  with AI-assisted tools (Claude Code), non-profit and private, and a
  **Delete all my data** button.

Made by Valatalo.

## Disclaimers

- **Not medical advice.** BMI is a rough screening number, not a diagnosis.
  It doesn't tell muscle from fat and suits some people poorly (athletes,
  pregnant people, older adults, anyone under 20).
- **Made with AI-assisted tools** (Claude Code).
- **Non-profit, on your device only, private.** The app has no network
  permission at all: no account, tracking or analytics. Everything stays on
  the phone and can be deleted from the About page.

To add an OpenRepos link, set `OPENREPOS_URL` in `qml/js/about.js`.

## Categories

WHO adult categories, judged on the BMI as displayed (one decimal), so the
label always matches the number:

| BMI | Category | Colour |
|---|---|---|
| below 18.5 | Underweight | blue `#3987e5` |
| 18.5–24.9 | Normal | green `#0ca30c` |
| 25.0–29.9 | Overweight | yellow `#fab219` |
| 30.0 and above | Obese | red `#d03b3b` |

The colours are always shown next to the category name, never on their
own, so the app works for colour-blind users too. The four colours were
checked with a palette validator: neighbouring colours stay distinguishable
under colour-vision deficiency (ΔE ≥ 11).

Adult categories are the same for every gender. For people under 20, BMI
is judged against age- and sex-specific growth charts instead, and the app
says so when your age is under 20.

## Where the data lives

One SQLite database (Qt `LocalStorage`) in
`~/.local/share/org.veetalat/bmitracker/`. Weights are stored in kilograms
and heights in centimetres, so switching units never changes your history.
The app runs sandboxed (Sailjail) with no extra permissions: it can't reach
the network or any of your other files.

## Building

With Docker, no SDK install needed. This uses the community
`coderus/sailfishos-platform-sdk` image, about 4.5 GB:

```sh
cd sailfish-bmi-tracker
./build-rpm.sh aarch64      # or armv7hl for older 32-bit phones
```

It builds against Sailfish OS 4.6, so the package also runs on 5.x. The RPM
lands in `RPMS/`.

## Installing

With Developer mode on, copy the RPM to the phone and run:

```sh
devel-su pkcon install-local ~/Downloads/harbour-bmitracker-1.2.0-1.aarch64.rpm
```

(or `devel-su rpm -U …` if pkcon refuses an unsigned package).

## Tests

```sh
node tests/test_bmi.js           # BMI maths, unit conversion, categories, parsing
tests/sdk-smoke-test.sh          # end to end in the Sailfish SDK (Docker)
tests/chart-background-test.sh   # the chart survives going to the background
```

`chart-background-test.sh` covers a 1.1 bug where the history chart was
missing after going to the home screen and back. Sailfish frees an app's
graphics memory in the background, and a QML `Canvas` then comes back blank
unless it paints again. The chart now repaints when the app, its window or
its drawing surface come back. The test renders the chart with a
non-persistent GL context on a virtual display, hides and shows the window,
and checks the chart looks the same. It fails on the 1.1 chart.

The smoke test builds a copy of the app with `tests/SmokeTest.qml` added,
runs it twice on Sailfish's own Qt and Silica, and checks the whole flow:
the pages get the app's data, the profile and weights save, everything is
still there after a restart, the profile page reopens filled in, and
nothing shows "NaN". It fails on any QML warning.

It exists because 1.0 lost everything: `MainPage { store: store }`
resolved `store` to the page's own empty property instead of the app's
data object, so pages saved into nothing. The data object is now called
`appStore`, and the smoke test fails on the old code.

`qml/js/bmi.js` is plain ES5 because Sailfish's Qt 5.6 JavaScript engine
predates `let`, `const`, arrow functions and template strings; the test
suite checks that none slip in.
