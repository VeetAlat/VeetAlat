# BMI Tracker for Sailfish OS

A native Silica app for logging your weight and following your body mass
index over time.

- Enter your **height** (cm or feet and inches), **age** and **gender** once.
- Log your **weight** in kilograms or pounds, with a date.
- See your BMI on a **blue / green / yellow / red** scale (underweight /
  normal / overweight / obese), your normal weight range for your height,
  and a **history chart** with the same colour bands. Tap or drag across
  the chart to see a measurement.
- Everything is **saved on the phone** and is there again the next time you
  open the app.
- The cover shows your latest BMI, and its **+** button opens "Add weight".

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
devel-su pkcon install-local ~/Downloads/harbour-bmitracker-1.0.0-1.aarch64.rpm
```

(or `devel-su rpm -U …` if pkcon refuses an unsigned package).

## Tests

```sh
node tests/test_bmi.js     # BMI maths, unit conversion, categories, parsing
```

`qml/js/bmi.js` is plain ES5 because Sailfish's Qt 5.6 JavaScript engine
predates `let`, `const`, arrow functions and template strings; the test
suite checks that none slip in.
