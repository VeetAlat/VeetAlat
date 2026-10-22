// Every example project, and the new-project template, compiles without
// errors or warnings and runs a minute of PLC time without failing.
// Run: node tests/test_examples.js
const fs = require("fs")
const path = require("path")
const vm = require("vm")

function load(file) {
    const ctx = {}
    vm.createContext(ctx)
    vm.runInContext(fs.readFileSync(path.join(__dirname, "../qml/js", file), "utf8").replace(/^\.pragma library\s*$/m, ""), ctx)
    return ctx
}
const ST = load("st.js"), EX = load("examples.js")

let failed = 0
function check(name, ok, detail) {
    console.log((ok ? "ok   - " : "FAIL - ") + name + (ok || detail === undefined ? "" : "  -> " + JSON.stringify(detail)))
    if (!ok) failed = 1
}

// Runs for seconds of PLC time in 20 ms cycles; returns the runtime or the error.
function runFor(source, seconds) {
    const r = ST.compile(source)
    if (!r.ok) return { errors: r.errors }
    const plc = ST.createRuntime(r.app)
    for (let t = 0; t <= seconds * 1000; t += 20) {
        const e = plc.cycle(t)
        if (e) return { error: e }
    }
    return { plc: plc, warnings: r.warnings }
}

const all = EX.projects.concat([{ name: "New project template", source: EX.TEMPLATE }])
for (const ex of all) {
    const r = ST.compile(ex.source)
    check(ex.name + ": compiles", r.ok, r.errors)
    check(ex.name + ": no warnings", r.warnings.length === 0, r.warnings)
    const res = runFor(ex.source, 60)
    check(ex.name + ": runs a minute without failing", !!res.plc, res.error || res.errors)
}

const v = (res, p) => res.plc.value("PLC_PRG." + p)
let res = runFor(EX.projects[0].source, 5)
check("Blinker blinks about every 500 ms", v(res, "blinks") >= 9 && v(res, "blinks") <= 10, v(res, "blinks"))
res = runFor(EX.projects[1].source, 13)
check("Traffic light completes a cycle (4 + 1 + 6 + 1 s, plus a cycle per change)", v(res, "cycles") === 1, v(res, "cycles"))
check("Traffic light shows one colour (or red+yellow)", [v(res, "redLamp"), v(res, "yellowLamp"), v(res, "greenLamp")].filter(Boolean).length >= 1)
res = runFor(EX.projects[2].source, 60)
const level = res.plc.value("PLC_PRG.tank.level")
check("Tank level stays within the hysteresis", level > 15 && level < 85, level)
check("Tank pump has started", v(res, "pumpStarts.CV") >= 1)
res = runFor(EX.projects[3].source, 10)
check("Box counter counts boxes", v(res, "totalBoxes") >= 13 && v(res, "totalBoxes") <= 15, v(res, "totalBoxes"))
check("Box counter packs batches", v(res, "batches") === 2, v(res, "batches"))
check("Box counter message", /^Batch 3: \d\/6$/.test(v(res, "message")), v(res, "message"))
res = runFor(EX.projects[4].source, 3)
const sorted = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10].map(i => res.plc.value("PLC_PRG.sorter.sorted[" + i + "]"))
check("Sorter sorts", sorted.every((x, i) => i === 0 || sorted[i - 1] <= x), sorted)
check("Average is the buffer's mean", Math.abs(v(res, "mean") - [1, 2, 3, 4, 5, 6, 7, 8, 9, 10].map(i => v(res, "buffer[" + i + "]")).reduce((a, b) => a + b) / 10) < 1e-9)



// Every code sample in the ST reference compiles, without warnings.
const REF = load("reference.js")
for (const sec of REF.sections) {
    if (!sec.code) continue
    const r = ST.compile(sec.code)
    check("reference '" + sec.title + "' compiles", r.ok, r.errors)
    check("reference '" + sec.title + "' has no warnings", r.warnings.length === 0, r.warnings)
    const res = runFor(sec.code, 1)
    check("reference '" + sec.title + "' runs", !!res.plc, res.error)
}
process.exit(failed)
