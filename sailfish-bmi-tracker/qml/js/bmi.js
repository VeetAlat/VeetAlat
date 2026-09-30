.pragma library

// BMI maths and unit conversion. Plain ES5: Sailfish OS's QML engine
// (Qt 5.6) has no let/const, arrow functions or template strings.
//
// Everything is stored in kg and cm; pounds and feet/inches exist only
// at the edges, for input and display.

var KG_PER_LB = 0.45359237
var CM_PER_IN = 2.54

// WHO adult categories. Colours follow the status palette: underweight
// blue, normal green, overweight yellow, obese red. Colour never carries
// the meaning alone; the name is always shown next to it.
var categories = [
    { key: "under",  name: "Underweight", shortName: "Under",  from: 0,    to: 18.5, color: "#3987e5" },
    { key: "normal", name: "Normal",      shortName: "Normal", from: 18.5, to: 25,   color: "#0ca30c" },
    { key: "over",   name: "Overweight",  shortName: "Over",   from: 25,   to: 30,   color: "#fab219" },
    { key: "obese",  name: "Obese",       shortName: "Obese",  from: 30,   to: 999,  color: "#d03b3b" }
]

// The part of the BMI axis the scale and chart show.
var SCALE_MIN = 15
var SCALE_MAX = 40

function kgFromLb(lb) { return lb * KG_PER_LB }
function lbFromKg(kg) { return kg / KG_PER_LB }

function cmFromFtIn(ft, inch) { return (ft * 12 + inch) * CM_PER_IN }

// { ft, inch } with inches rounded to 0.1, never showing 12 in.
function ftInFromCm(cm) {
    var totalIn = Math.round(cm / CM_PER_IN * 10) / 10
    var ft = Math.floor(totalIn / 12)
    var inch = Math.round((totalIn - ft * 12) * 10) / 10
    if (inch >= 12) {
        ft += 1
        inch = 0
    }
    return { ft: ft, inch: inch }
}

// Accepts "72.5" and "72,5" (Finnish and many other locales use a comma).
// Returns NaN for anything that isn't a plain positive number.
function parseNumber(text) {
    var s = String(text === undefined || text === null ? "" : text).trim().replace(",", ".")
    if (!/^\d+(\.\d+)?$|^\.\d+$/.test(s)) return NaN
    return parseFloat(s)
}

function bmi(kg, cm) {
    if (!(kg > 0) || !(cm > 0)) return NaN
    var m = cm / 100
    return kg / (m * m)
}

// BMI as displayed, one decimal. Categories use this rounded value so the
// label always agrees with the number on screen (24.96 shows as 25.0 and
// is overweight, not normal).
function rounded(value) { return Math.round(value * 10) / 10 }

function category(value) {
    if (isNaN(value)) return null
    var v = rounded(value)
    for (var i = 0; i < categories.length; i++) {
        if (v < categories[i].to) return categories[i]
    }
    return categories[categories.length - 1]
}

// Weight range (kg) that gives a normal BMI (18.5-24.9) at this height.
function healthyRange(cm) {
    var m = cm / 100
    return { min: 18.5 * m * m, max: 24.9 * m * m }
}

// Adult categories apply from 20; below that BMI is judged against
// age- and sex-specific growth charts (WHO 5-19 years, CDC 2-19 years).
function isAdult(age) { return !(age > 0) || age >= 20 }

// Position of a BMI on the scale, 0..1, clamped.
function scalePosition(value) {
    var p = (value - SCALE_MIN) / (SCALE_MAX - SCALE_MIN)
    return Math.max(0, Math.min(1, p))
}

function formatWeight(kg, unit) {
    if (unit === "lb") return lbFromKg(kg).toFixed(1) + " lb"
    return kg.toFixed(1) + " kg"
}

function formatHeight(cm, unit) {
    if (unit === "ftin") {
        var f = ftInFromCm(cm)
        return f.ft + "′ " + f.inch + "″"
    }
    return Math.round(cm) + " cm"
}

function formatRange(range, unit) {
    if (unit === "lb") {
        return lbFromKg(range.min).toFixed(0) + "–" + lbFromKg(range.max).toFixed(0) + " lb"
    }
    return range.min.toFixed(1) + "–" + range.max.toFixed(1) + " kg"
}
