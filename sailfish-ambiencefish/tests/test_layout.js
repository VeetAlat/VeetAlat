// Unit tests for qml/js/layout.js. Run: node tests/test_layout.js
const fs = require("fs"), path = require("path"), vm = require("vm")
const src = fs.readFileSync(path.join(__dirname, "../qml/js/layout.js"), "utf8")
const L = {}
vm.createContext(L)
vm.runInContext(src.replace(/^\.pragma library\s*$/m, ""), L)

let failed = 0
function check(name, ok, detail) {
    console.log((ok ? "ok   - " : "FAIL - ") + name + (ok || detail === undefined ? "" : "  -> " + JSON.stringify(detail)))
    if (!ok) failed = 1
}
const near = (a, b) => Math.abs(a - b) < 1e-9
const ratio = 1080 / 2400 // a tall phone screen

// A landscape photo (3:2) and a portrait one (3:4).
for (const [name, aspect] of [["landscape photo", 1.5], ["portrait photo", 0.75], ["square photo", 1]]) {
    const fill = L.layoutFor("fillPortrait", aspect, ratio)
    check(name + ": fill screen covers the portrait screen", L.coverage(fill, aspect, ratio).portrait)
    const p = L.photoRect(fill, aspect)
    check(name + ": ... and no more than needed", near(p.width, ratio) || near(p.height, 1), p)
    const fit = L.layoutFor("fitPortrait", aspect, ratio)
    const f = L.photoRect(fit, aspect), pr = L.portraitRect(ratio)
    check(name + ": whole photo fits on the portrait screen", L.covers(pr, f), f)
    check(name + ": ... as big as it can", near(f.width, ratio) || near(f.height, 1), f)
    check(name + ": fill square covers both screens", L.coverage(L.layoutFor("fillSquare", aspect, ratio), aspect, ratio).landscape
          && L.coverage(L.layoutFor("fillSquare", aspect, ratio), aspect, ratio).portrait)
    check(name + ": fill landscape covers the landscape screen", L.coverage(L.layoutFor("fillLandscape", aspect, ratio), aspect, ratio).landscape)
    check(name + ": fit square stays in the square", L.covers({ x: 0, y: 0, width: 1, height: 1 }, L.photoRect(L.layoutFor("fitSquare", aspect, ratio), aspect)))
}
check("a landscape photo filling the screen doesn't cover landscape (that's what the blur is for)",
      !L.coverage(L.layoutFor("fillPortrait", 0.75, ratio), 0.75, ratio).landscape)
const z = L.zoomed({ cx: 0.5, cy: 0.5, scale: 1 }, 2, 0.25, 0.5)
check("zooming keeps the pinch point still", near(z.scale, 2) && near(z.cx, 0.75) && near(z.cy, 0.5), z)
check("zoom has limits", L.zoomed({ cx: 0.5, cy: 0.5, scale: 1 }, 1000, 0.5, 0.5).scale === 10)
check("a quarter turn swaps the aspect", L.turnedAspect(1200, 800, 90) === 800 / 1200 && L.turnedAspect(1200, 800, 180) === 1.5)
check("screens are centred", near(L.portraitRect(ratio).x * 2 + ratio, 1) && near(L.landscapeRect(ratio).y * 2 + ratio, 1))
check("ES5 only", !/\b(let|const)\s|=>|`/.test(src))
process.exit(failed)
