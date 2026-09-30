// Unit tests for qml/js/bmi.js. Run: node tests/test_bmi.js
// The file is a QML ".pragma library", so strip that line and evaluate it
// as a plain script.
const fs = require("fs")
const path = require("path")
const vm = require("vm")

const src = fs.readFileSync(path.join(__dirname, "../qml/js/bmi.js"), "utf8")
    .replace(/^\.pragma library\s*$/m, "")
const B = {}
vm.createContext(B)
vm.runInContext(src, B)

let failed = 0
function check(name, ok) {
    console.log((ok ? "ok   - " : "FAIL - ") + name)
    if (!ok) failed = 1
}
const near = (a, b, eps = 1e-6) => Math.abs(a - b) < eps

check("bmi 70 kg / 175 cm = 22.86", near(B.bmi(70, 175), 22.857142857, 1e-6))
check("bmi rejects zero height", isNaN(B.bmi(70, 0)))
check("bmi rejects empty weight", isNaN(B.bmi(NaN, 175)))

check("lb -> kg", near(B.kgFromLb(154), 69.85322498))
check("kg -> lb round trip", near(B.lbFromKg(B.kgFromLb(200)), 200))
check("5 ft 9 in = 175.26 cm", near(B.cmFromFtIn(5, 9), 175.26))
const f = B.ftInFromCm(175.26)
check("175.26 cm = 5 ft 9 in", f.ft === 5 && f.inch === 9)
const g = B.ftInFromCm(182.87) // 71.996 in -> 72.0 in -> 6 ft 0 in, not 5 ft 12 in
check("no 12-inch rollover", g.ft === 6 && g.inch === 0)

check("parse dot decimal", B.parseNumber("72.5") === 72.5)
check("parse comma decimal", B.parseNumber("72,5") === 72.5)
check("parse trims spaces", B.parseNumber(" 80 ") === 80)
check("parse rejects text", isNaN(B.parseNumber("abc")))
check("parse rejects negative", isNaN(B.parseNumber("-5")))
check("parse rejects empty", isNaN(B.parseNumber("")))
check("parse rejects two separators", isNaN(B.parseNumber("1.2.3")))

const cat = v => B.category(v).key
check("18.4 underweight", cat(18.4) === "under")
check("18.5 normal", cat(18.5) === "normal")
check("24.9 normal", cat(24.9) === "normal")
check("24.96 shows as 25.0 so overweight", cat(24.96) === "over")
check("25.0 overweight", cat(25) === "over")
check("29.9 overweight", cat(29.9) === "over")
check("30.0 obese", cat(30) === "obese")
check("55 obese", cat(55) === "obese")
check("NaN has no category", B.category(NaN) === null)
check("four colours: blue green yellow red",
    B.categories.map(c => c.color).join() === "#3987e5,#0ca30c,#fab219,#d03b3b")

const r = B.healthyRange(175)
check("healthy range at 175 cm is 56.7-76.3 kg", near(r.min, 56.65625) && near(r.max, 76.25625))
check("range text kg", B.formatRange(r, "kg") === "56.7–76.3 kg")
check("range text lb", B.formatRange(r, "lb") === "125–168 lb")

check("adult at 20", B.isAdult(20))
check("not adult at 15", !B.isAdult(15))
check("unknown age treated as adult", B.isAdult(NaN))

check("scale clamps low", B.scalePosition(10) === 0)
check("scale clamps high", B.scalePosition(50) === 1)
check("scale midpoint", near(B.scalePosition(27.5), 0.5))

check("weight text kg", B.formatWeight(72.34, "kg") === "72.3 kg")
check("weight text lb", B.formatWeight(B.kgFromLb(160), "lb") === "160.0 lb")
check("height text cm", B.formatHeight(175.4, "cm") === "175 cm")
check("height text ft/in", B.formatHeight(175.26, "ftin") === "5′ 9″")

check("no NaN: weight", B.formatWeight(NaN, "kg") === "\u2013" && B.formatWeight(undefined, "lb") === "\u2013")
check("no NaN: height", B.formatHeight(0, "cm") === "\u2013" && B.formatHeight(NaN, "ftin") === "\u2013")
check("no NaN: range", B.formatRange(B.healthyRange(0), "kg") === "\u2013" && B.formatRange(null, "kg") === "\u2013")
check("no NaN: bmi", B.formatBmi(NaN) === "\u2013" && B.formatBmi(22.857) === "22.9")

// Sailfish's Qt 5.6 JS engine is ES5: make sure no newer syntax slipped in.
check("ES5 only (no let/const/arrow/template)",
    !/\b(let|const)\s|=>|`/.test(src))

process.exit(failed)
