import QtQuick 2.0
import Sailfish.Silica 1.0
import "js/layout.js" as Layout

// Injected into a copy of the app by tests/sdk-smoke-test.sh (never
// shipped). Runs without a window on Sailfish's Qt: the composer renders
// the test photos (tests/fixtures) and the pixels are checked; then the
// editor opens a photo, its presets and preview work, Save makes the
// square, and making the ambience fails cleanly (the SDK has no ambience
// service).
Item {
    id: smoke

    property var testedWindow
    property var testedComposer
    property int failures: 0
    property int step: 0
    property var editor
    property var done
    property string out: ""

    function check(name, ok) {
        console.log((ok ? "SMOKE PASS " : "SMOKE FAIL ") + name)
        if (!ok) failures++
    }
    function finish() {
        ticker.stop()
        console.log("SMOKE DONE failures=" + failures)
        Qt.quit()
    }
    function ready(cond, what) {
        if (cond) { ticker.waited = 0; return true }
        if (++ticker.waited > 200) { check(what + " in time", false); finish(); return false }
        step--
        return false
    }
    function fixture(name) { return fixturesDir + "/" + name }
    // Renders a fixture to a PNG and returns the pixel reader for it.
    function render(name, layout) {
        var target = testedComposer.outputDir + "/test-" + (++renders) + ".png"
        var r = testedComposer.render(fixture(name), layout, target)
        lastRender = r
        return function(x, y) { return testedComposer.pixelAt(target, x, y) }
    }
    property int renders: 0
    property var lastRender: null
    function near(p, r, g, b, tol) {
        return Math.abs(p.red - r) <= tol && Math.abs(p.green - g) <= tol && Math.abs(p.blue - b) <= tol
    }

    Component.onCompleted: ticker.start()

    Timer {
        id: ticker
        interval: 100
        repeat: true
        property int waited: 0
        onTriggered: {
            var c = smoke.testedComposer
            var stack = smoke.testedWindow.pageStack
            switch (smoke.step++) {
            case 0:
                if (!stack.currentPage || stack.busy) { smoke.step--; return }
                console.log("SMOKE RUN 1")
                var a = c.inspect(smoke.fixture("landscape.png"))
                smoke.check("a PNG's size", a.ok && a.width === 1200 && a.height === 800)
                var b = c.inspect(smoke.fixture("rotated.jpg"))
                smoke.check("a phone photo's EXIF turn is taken into account", b.ok && b.width === 600 && b.height === 800)
                smoke.check("a missing photo is reported", c.inspect(smoke.fixture("nope.jpg")).ok === false)

                var px = smoke.render("landscape.png", { size: 1024, cx: 0.5, cy: 0.5, scale: 1, background: "black" })
                smoke.check("rendered at the size asked", smoke.lastRender.ok && smoke.lastRender.width === 1024 && smoke.lastRender.height === 1024)
                smoke.check("the photo's left half where it was put", smoke.near(px(0.25, 0.5), 220, 40, 40, 6))
                smoke.check("the photo's right half where it was put", smoke.near(px(0.75, 0.5), 40, 60, 220, 6))
                smoke.check("black above the photo", smoke.near(px(0.5, 0.08), 0, 0, 0, 2))

                px = smoke.render("landscape.png", { size: 1024, cx: 0.5, cy: 0.5, scale: 1, background: "blur", blur: 0.6, dim: 0 })
                smoke.check("blur: red photo above its red side", px(0.03, 0.03).red > px(0.03, 0.03).blue + 80)
                smoke.check("blur: blue above its blue side", px(0.97, 0.03).blue > px(0.97, 0.03).red + 80)
                var mid = px(0.5, 0.03)
                smoke.check("blur: red and blue blend in the middle", mid.red > 70 && mid.blue > 70)
                smoke.check("blur: the photo itself stays sharp", smoke.near(px(0.25, 0.5), 220, 40, 40, 6))

                px = smoke.render("landscape.png", { size: 512, scale: 1, background: "blur", blur: 0.6, dim: 1 })
                smoke.check("darkened all the way: black around", smoke.near(px(0.03, 0.03), 0, 0, 0, 3))
                px = smoke.render("landscape.png", { size: 512, scale: 1, background: "colour", dim: 0 })
                smoke.check("the photo's own colour around", smoke.near(px(0.03, 0.03), 130, 50, 130, 14))
                px = smoke.render("landscape.png", { size: 512, scale: 1, background: "blur", blur: 0.6, dim: 0.5 })
                var dimmed = px(0.03, 0.03)
                smoke.check("darkened by half", dimmed.red > 80 && dimmed.red < 140)

                px = smoke.render("rotated.jpg", { size: 1024, cx: 0.5, cy: 0.5, scale: 0.75, background: "black" })
                smoke.check("an EXIF-turned photo comes out upright (purple left)", smoke.near(px(0.3, 0.5), 120, 40, 160, 14))
                smoke.check("an EXIF-turned photo comes out upright (yellow right)", smoke.near(px(0.7, 0.5), 230, 200, 40, 14))

                px = smoke.render("landscape.png", { size: 1024, cx: 0.5, cy: 0.5, scale: 800 / 1200, rotation: 90, background: "black" })
                smoke.check("turned a quarter: red on top", smoke.near(px(0.5, 0.25), 220, 40, 40, 6))
                smoke.check("turned a quarter: blue below", smoke.near(px(0.5, 0.75), 40, 60, 220, 6))

                px = smoke.render("landscape.png", { cx: 0.2, cy: 0.5, scale: 0.4, background: "black" })
                smoke.check("2048 x 2048 by default", smoke.lastRender.width === 2048)
                smoke.check("placed off centre", smoke.near(px(0.1, 0.5), 220, 40, 40, 6) && smoke.near(px(0.3, 0.5), 40, 60, 220, 6))
                smoke.check("and nothing at the old centre", smoke.near(px(0.6, 0.5), 0, 0, 0, 2))

                smoke.editor = stack.push(Qt.resolvedUrl("pages/EditorPage.qml"),
                                          { composer: c, source: smoke.fixture("landscape.png") }, PageStackAction.Immediate)
                break
            case 1:
                var ed = smoke.editor
                if (!smoke.ready(ed.previewUrl !== "", "the preview")) break
                smoke.check("the editor reads the photo", ed.photoOk && ed.photoWidth === 1200 && ed.photoHeight === 800)
                var r = ed.screenRatio
                smoke.check("the screen's shape is known", r > 0.3 && r < 1)
                smoke.check("it starts filling the upright screen", ed.preset === "fillPortrait" && Math.abs(ed.photoScale - 1.5) < 1e-6
                            && ed.coverage.portrait)
                smoke.check("the photo on the canvas is placed by the layout",
                            Math.abs(ed.photoItem.width - 1.5 * ed.canvasItem.width) < 0.5
                            && Math.abs(ed.photoItem.x - (0.5 - 0.75) * ed.canvasItem.width) < 0.5)
                ed.apply("fitPortrait")
                smoke.check("'Whole photo' fits it on the upright screen", Math.abs(ed.photoScale - r) < 1e-6 && !ed.coverage.portrait)
                ed.apply("fillSquare")
                smoke.check("'Fill square' covers both screens", ed.coverage.portrait && ed.coverage.landscape)
                var before = ed.previewUrl
                ed.fill = "colour"
                smoke.mark = before
                break
            case 2:
                if (!smoke.ready(smoke.editor.previewUrl !== smoke.mark, "a new preview")) break
                smoke.check("changing the surroundings makes a new preview", smoke.editor.previewUrl !== "")
                smoke.editor.fill = "blur"
                smoke.editor.rotate()
                smoke.check("Turn: a quarter turn, placed again", smoke.editor.turn === 90
                            && Math.abs(smoke.editor.aspect - 800 / 1200) < 1e-6 && smoke.editor.preset === "fillSquare")
                smoke.editor.apply("fillPortrait")
                smoke.editor.save()
                smoke.check("saving shows it's busy", c.busy)
                break
            case 3:
                if (!smoke.ready(!c.busy && stack.currentPage !== smoke.editor && !stack.busy, "the saved picture")) break
                smoke.done = stack.currentPage
                var path = smoke.done.path
                smoke.check("saved in Pictures/AmbienceFish", path.indexOf(c.outputDir + "/AmbienceFish-") === 0 && /\.jpg$/.test(path))
                var p = c.pixelAt(path, 0.5, 0.25)
                smoke.check("the saved square is 2048 or more", p.width === p.height && p.width >= 2048)
                smoke.check("the saved picture is turned and placed (red on top)", p.red > 180 && p.blue < 90)
                var q = c.pixelAt(path, 0.5, 0.75)
                smoke.check("... and blue below", q.blue > 180 && q.red < 90)
                c.ambienceTimeout = 4000 // nothing will answer here
                smoke.done.makeAmbience(false)
                smoke.check("making the ambience starts", smoke.done.working)
                break
            case 4:
                if (!smoke.ready(!smoke.done.working, "the ambience service's answer")) break
                smoke.check("no ambience service here: it says so, and how else to do it",
                            /couldn't be made/.test(smoke.done.message) && /Gallery/.test(smoke.done.message) && !smoke.done.created)
                var picker = stack.push("Sailfish.Pickers.FilePickerPage", {}, PageStackAction.Immediate)
                smoke.check("the file picker opens", picker !== null)
                stack.pop(null, PageStackAction.Immediate)
                var about = stack.push(Qt.resolvedUrl("pages/AboutPage.qml"), {}, PageStackAction.Immediate)
                smoke.check("About: made by Valatalo", about.author === "Valatalo")
                stack.pop(null, PageStackAction.Immediate)
                smoke.finish()
                break
            }
        }
    }
    property string mark: ""
}
