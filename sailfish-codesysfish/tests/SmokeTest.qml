import QtQuick 2.0
import Sailfish.Silica 1.0
import "js/store.js" as Store
import "js/examples.js" as Examples

// Injected into a copy of the app by tests/sdk-smoke-test.sh (never
// shipped). The app runs without a window, through its real pages.
// Run 1: the examples are there; Blinker opens with its code highlighted,
// builds, runs and blinks in the online view; values are written, the PLC
// is stepped and reset; a runtime error leads to its line, a compile
// error is listed and marked; snippets keep the indentation; projects are
// made, renamed and deleted. Run 2 (a restart): it was all saved.
Item {
    id: smoke

    property var testedWindow
    property var testedPlc
    property int failures: 0
    property int step: 0
    property var home
    property var editor
    property var online
    property real mark: 0
    property int blinksBefore: 0

    function check(name, ok) {
        console.log((ok ? "SMOKE PASS " : "SMOKE FAIL ") + name)
        if (!ok) failures++
    }
    function finish() {
        ticker.stop()
        console.log("SMOKE DONE failures=" + failures)
        Qt.quit()
    }
    // Waits (up to 15 s) for cond; false while still waiting.
    function ready(cond, what) {
        if (cond) { ticker.waited = 0; return true }
        if (++ticker.waited > 150) { check(what + " in time", false); finish(); return false }
        step--
        return false
    }
    function projectNamed(name) {
        var list = Store.list()
        for (var i = 0; i < list.length; i++) if (list[i].name === name) return list[i]
        return null
    }
    function value(path) { return testedPlc.runtime ? testedPlc.runtime.value(path) : undefined }

    Component.onCompleted: ticker.start()

    Timer {
        id: ticker
        interval: 100
        repeat: true
        property int waited: 0
        onTriggered: {
            var plc = smoke.testedPlc
            var stack = smoke.testedWindow.pageStack
            switch (smoke.step++) {
            case 0:
                smoke.home = stack.currentPage
                if (!smoke.home || stack.busy) { smoke.step--; return }
                if (Store.setting("smoke", "") === "1") { smoke.step = 100; return }
                console.log("SMOKE RUN 1")
                var names = smoke.home.projects.map(function(p) { return p.name }).join(",")
                smoke.check("the five examples, first one first",
                            names === "Blinker,Traffic light,Tank level,Box counter,Arrays and functions")
                smoke.check("nothing runs yet", !plc.loaded && !plc.running)
                smoke.editor = smoke.home.open(smoke.projectNamed("Blinker").id)
                break
            case 1:
                if (!smoke.ready(!stack.busy, "the editor")) break
                var ed = smoke.editor
                smoke.check("the editor shows the project's code", ed.editorArea.text === Examples.projects[0].source)
                smoke.check("the code is highlighted", ed.codeHighlighter.textDocument !== null && ed.codeHighlighter.highlightedBlocks > 10)
                smoke.check("the cursor starts on line 1", ed.cursorLine === 1)
                var r = ed.build()
                smoke.check("Blinker builds", r.ok && ed.buildStatus === "Build OK" && ed.messages.length === 0)
                plc.setCycleMs(20)
                smoke.online = ed.run()
                smoke.check("Run starts the PLC and opens the online view",
                            smoke.online !== null && plc.running && plc.projectName === "Blinker" && plc.mainName === "PLC_PRG")
                smoke.mark = Date.now()
                break
            case 2:
                if (!smoke.ready(!stack.busy && plc.plcTime >= 1300, "1.3 s of PLC time")) break
                smoke.check("it blinks", smoke.value("PLC_PRG.blinks") >= 2)
                smoke.check("PLC time follows the clock", plc.plcTime <= Date.now() - smoke.mark + 200)
                var rows = smoke.online.rows
                var paths = []
                for (var i = 0; i < rows.count; i++) paths.push(rows.get(i).path)
                smoke.check("the online view lists the variables",
                            paths.join() === "PLC_PRG.pulse,PLC_PRG.lamp,PLC_PRG.blinks,PLC_PRG.period")
                smoke.check("lamp shows as a BOOL", rows.get(1).kind === "bool" && /^(TRUE|FALSE)$/.test(rows.get(1).value))
                smoke.check("values refresh while running", rows.get(2).value === String(smoke.value("PLC_PRG.blinks"))
                            || parseInt(rows.get(2).value, 10) >= 2)
                smoke.check("writing a value", smoke.online.write("PLC_PRG.period", "T#100MS") === "" && smoke.value("PLC_PRG.period") === 100)
                smoke.blinksBefore = smoke.value("PLC_PRG.blinks")
                smoke.mark = plc.plcTime
                break
            case 3:
                if (!smoke.ready(plc.plcTime >= smoke.mark + 700, "0.7 s more")) break
                smoke.check("the new period blinks faster", smoke.value("PLC_PRG.blinks") - smoke.blinksBefore >= 4)
                plc.stop()
                var c = plc.cycles
                plc.step()
                smoke.check("Step runs exactly one cycle", plc.cycles === c + 1 && !plc.running)
                smoke.online.toggle("PLC_PRG.pulse")
                var opened = false
                for (var k = 0; k < smoke.online.rows.count; k++) if (smoke.online.rows.get(k).path === "PLC_PRG.pulse.ET") opened = true
                smoke.check("a function block opens to its inputs and outputs", opened)
                plc.reset()
                smoke.check("Reset: initial values, cycle 0", plc.cycles === 0 && smoke.value("PLC_PRG.blinks") === 0
                            && smoke.value("PLC_PRG.period") === 500)
                var dialog = stack.push(Qt.resolvedUrl("pages/WriteDialog.qml"),
                                        { plc: plc, path: "PLC_PRG.blinks", name: "blinks", typeName: "INT", current: "0" },
                                        PageStackAction.Immediate)
                smoke.check("the write dialog checks the value", dialog.problem === "" && dialog.canAccept)
                stack.pop(null, PageStackAction.Immediate)
                // Back to the code.
                stack.pop(smoke.editor, PageStackAction.Immediate)
                smoke.check("back in the editor", stack.currentPage === smoke.editor)
                // A runtime error, on line 7.
                smoke.editor.editorArea.text = "PROGRAM PLC_PRG\nVAR\n    n : INT;\n    z : INT;\nEND_VAR\nn := n + 1;\nn := n / z;\nEND_PROGRAM\n"
                smoke.online = smoke.editor.run()
                smoke.check("the broken program runs", smoke.online !== null)
                break
            case 4:
                if (!smoke.ready(plc.error !== null && !stack.busy, "the runtime error")) break
                smoke.check("division by zero stops the PLC at its line",
                            !plc.running && plc.error.line === 7 && /Division by zero/.test(plc.error.message))
                smoke.online.showError()
                break
            case 5:
                if (!smoke.ready(!stack.busy, "back to the code")) break
                smoke.check("the error's line in the code", stack.currentPage === smoke.editor && smoke.editor.cursorLine === 7)
                var ed2 = smoke.editor
                ed2.editorArea.text = "PROGRAM PLC_PRG\nVAR\n    a : INT;\nEND_VAR\na := 1;\na := b;\nEND_PROGRAM\n"
                var r2 = ed2.build()
                smoke.check("a compile error is listed with its line",
                            !r2.ok && ed2.messages.length === 1 && ed2.messages[0].line === 6 && ed2.buildStatus === "1 error")
                smoke.check("and marked in the code", ed2.codeHighlighter.errorLine === 6)
                ed2.goToLine(6, 6)
                smoke.check("tapping it goes to the line", ed2.cursorLine === 6)
                smoke.check("Run doesn't start broken code", ed2.run() === null)
                // Snippets follow the indentation.
                ed2.editorArea.text = "    a"
                ed2.editorArea.cursorPosition = 5
                ed2.insert("IF  THEN\n    \nEND_IF", 3)
                smoke.check("a snippet keeps the indentation",
                            ed2.editorArea.text === "    aIF  THEN\n        \n    END_IF" && ed2.editorArea.cursorPosition === 8)
                ed2.editorArea.text = "x :="
                ed2.editorArea.cursorPosition = 4
                ed2.insert(";")
                smoke.check("a symbol goes in at the cursor", ed2.editorArea.text === "x :=;" && ed2.editorArea.cursorPosition === 5)
                // Enter keeps the indentation of the line before (typed, as the keyboard does).
                ed2.editorArea.text = "    x"
                ed2.editorArea.cursorPosition = 5
                ed2.editorArea._editor.insert(5, "\n")
                smoke.check("a new line keeps the indentation", ed2.editorArea.text === "    x\n    ")
                // The real code back, with a mark.
                ed2.editorArea.text = Examples.projects[0].source + "// smoke\n"
                ed2.save()
                smoke.check("saved", !ed2.dirty && Store.get(ed2.projectId).source === Examples.projects[0].source + "// smoke\n")
                stack.pop(smoke.home, PageStackAction.Immediate)
                break
            case 6:
                if (!smoke.ready(!stack.busy, "the project list")) break
                var id = smoke.home.create("Smoke test", Examples.TEMPLATE)
                smoke.check("a new project", Store.get(id) !== null && smoke.home.projects.length === 6)
                Store.rename(id, "Smoke renamed")
                Store.remove(smoke.projectNamed("Box counter").id)
                smoke.home.refresh()
                smoke.check("renamed and deleted", smoke.projectNamed("Smoke renamed") !== null && smoke.projectNamed("Box counter") === null)
                var help = stack.push(Qt.resolvedUrl("pages/HelpPage.qml"), {}, PageStackAction.Immediate)
                smoke.check("the reference opens", help !== null)
                stack.pop(null, PageStackAction.Immediate)
                var about = stack.push(Qt.resolvedUrl("pages/AboutPage.qml"), {}, PageStackAction.Immediate)
                smoke.check("About: made by Valatalo", about.author === "Valatalo" && about.version === "0.1.0")
                stack.pop(null, PageStackAction.Immediate)
                plc.setCycleMs(50)
                Store.setSetting("smoke", "1")
                smoke.finish()
                break

            case 100:
                console.log("SMOKE RUN 2")
                var names2 = smoke.home.projects.map(function(p) { return p.name })
                smoke.check("projects kept after a restart", names2.length === 5 && names2.indexOf("Smoke renamed") >= 0)
                smoke.check("a deleted example doesn't come back", names2.indexOf("Box counter") < 0)
                smoke.check("edited code kept", /\/\/ smoke\n$/.test(Store.get(smoke.projectNamed("Blinker").id).source))
                smoke.check("the cycle time kept", plc.cycleMs === 50)
                smoke.check("nothing runs after a restart", !plc.loaded)
                smoke.finish()
                break
            }
        }
    }
}
