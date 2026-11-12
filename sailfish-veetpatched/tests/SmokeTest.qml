import QtQuick 2.0
import Sailfish.Silica 1.0

// Injected into a copy of the app by tests/sdk-smoke-test.sh (never
// shipped). The script runs the real helper in a loop, standing in for
// systemd's veetpatched.path, on a copy of the home screen's AppLayer.qml.
// This taps the StatusBar switch on and off through the real page, asks
// for a home screen restart (which can't work in the SDK, and must say
// so), and checks what happens when the helper doesn't answer.
Item {
    id: smoke

    property var testedWindow
    property var testedPatcher
    property int failures: 0
    property int step: 0
    property var page
    property string realDir: ""

    function check(name, ok) {
        console.log((ok ? "SMOKE PASS " : "SMOKE FAIL ") + name)
        if (!ok) failures++
    }
    function finish() {
        ticker.stop()
        if (failures) testedPatcher.logEntries.forEach(function(e) { console.log("LOGENTRY " + e.time + " " + e.level + " [" + e.source + "] " + e.text) })
        console.log("SMOKE DONE failures=" + failures)
        Qt.quit()
    }
    function ready(cond, what) {
        if (cond) { ticker.waited = 0; return true }
        if (++ticker.waited > 250) { check(what + " in time", false); finish(); return false }
        step--
        return false
    }
    function findSwitch(item) {
        if (!item) return null
        if (item.hasOwnProperty("automaticCheck") && item.hasOwnProperty("description")) return item
        var kids = item.children || []
        for (var i = 0; i < kids.length; i++) {
            var f = findSwitch(kids[i])
            if (f) return f
        }
        return null
    }
    // Log entries matching a source, level and text.
    function logged(source, level, re) {
        var all = testedPatcher.logEntries
        for (var i = 0; i < all.length; i++) {
            var e = all[i]
            if ((!source || e.source === source) && (!level || e.level === level) && re.test(e.text)) return true
        }
        return false
    }
    function state() { return testedPatcher.patches.length > 0 ? testedPatcher.patches[0].state : "" }

    Component.onCompleted: ticker.start()

    Timer {
        id: ticker
        interval: 100
        repeat: true
        property int waited: 0
        onTriggered: {
            var p = smoke.testedPatcher
            var stack = smoke.testedWindow.pageStack
            switch (smoke.step++) {
            case 0:
                smoke.page = stack.currentPage
                if (!smoke.page || stack.busy) { smoke.step--; return }
                console.log("SMOKE RUN 1")
                smoke.check("the patches that ship are listed",
                            p.patches.length === 1 && p.patches[0].id === "statusbar" && p.patches[0].name === "StatusBar"
                            && /notch/.test(p.patches[0].description))
                smoke.check("opening the app asks the helper", p.busy)
                break
            case 1:
                if (!smoke.ready(!p.busy, "the helper's first answer")) break
                smoke.check("the helper answers", p.helperAnswers && p.lastResult.ok)
                smoke.check("StatusBar starts off", smoke.state() === "not-applied")
                var sw = smoke.findSwitch(smoke.page)
                smoke.check("its switch is on the page, off", sw !== null && !sw.checked && sw.enabled)
                sw.clicked(null)
                smoke.check("tapping it asks to apply", p.busy)
                break
            case 2:
                if (!smoke.ready(!p.busy, "applying")) break
                smoke.check("StatusBar is on", smoke.state() === "applied" && p.lastResult.ok && p.lastResult.state === "applied")
                smoke.check("the switch shows it", smoke.findSwitch(smoke.page).checked)
                smoke.check("it says to restart the home screen", /StatusBar is on. Restart the home screen/.test(smoke.page.note)
                            && smoke.page.restartPending)
                smoke.check("the log says what was done", /statusbar: applied/.test(p.log))
                smoke.check("app log: started, with its patches", smoke.logged("app", "INFO", /^VeetPatched 0\.2\.0 started; patches: statusbar$/))
                smoke.check("app log: the request it sent", smoke.logged("app", "INFO", /^sent request #\d+: apply statusbar$/))
                smoke.check("app log: the answer and how long it took", smoke.logged("app", "INFO", /^request #\d+ answered after \d+ ms: statusbar applied$/))
                smoke.check("helper log: the steps, with the file's checksum",
                            smoke.logged("helper", "INFO", /^statusbar: backed up to/) && smoke.logged("helper", "INFO", /^statusbar: applied; .* sha256 [0-9a-f]{12}$/))
                smoke.check("helper log: the request and the phone's context",
                            smoke.logged("helper", "INFO", /^request #\d+: apply statusbar$/) && smoke.logged("helper", "INFO", /^context: Sailfish OS/))
                var times = p.logEntries.map(function(e) { return e.time })
                smoke.check("the merged log is in time order", times.every(function(t, i) { return i === 0 || times[i - 1] <= t }))
                smoke.check("copying gives both logs as text", /\[helper\] statusbar: applied/.test(p.log) && /\[app\] sent request/.test(p.log))
                p.restartHome()
                break
            case 3:
                if (!smoke.ready(!p.busy, "the restart's answer")) break
                smoke.check("no home screen here: it says so", smoke.page.noteIsError && /couldn't be restarted/.test(smoke.page.note)
                            && smoke.page.restartPending)
                smoke.check("still on after that", smoke.state() === "applied")
                smoke.check("the failed restart is an ERROR in both logs, with why",
                            smoke.logged("helper", "ERROR", /^restart: failed as /) && smoke.logged("helper", "WARN", /^restart: systemctl --user -M didn't work/)
                            && smoke.logged("app", "ERROR", /^request #\d+ failed after \d+ ms: The home screen couldn't be restarted/))
                smoke.findSwitch(smoke.page).clicked(null)
                break
            case 4:
                if (!smoke.ready(!p.busy, "unapplying")) break
                smoke.check("StatusBar is off again", smoke.state() === "not-applied" && smoke.page.note.indexOf("StatusBar is off") === 0)
                smoke.check("the log has it", /statusbar: removed/.test(p.log))
                // A helper that doesn't answer.
                smoke.realDir = p.dataDir
                p.timeout = 1500
                p.dataDir = smoke.realDir + "/nobody-listens"
                p.refresh()
                break
            case 5:
                if (!smoke.ready(!p.busy, "the timeout")) break
                smoke.check("no answer: it says so and how to fix it", !p.helperAnswers && !p.lastResult.ok
                            && /didn't answer. Restart the phone/.test(p.lastResult.message))
                smoke.check("app log: the timeout is an ERROR", smoke.logged("app", "ERROR", /^no answer to request #\d+ after 1\.5 s: the helper isn't running/))
                p.dataDir = smoke.realDir
                p.timeout = 15000
                p.refresh()
                break
            case 6:
                if (!smoke.ready(!p.busy, "the helper again")) break
                smoke.check("when it answers again, all's well", p.helperAnswers && p.lastResult.ok)
                var log = stack.push(Qt.resolvedUrl("pages/LogPage.qml"), { patcher: p }, PageStackAction.Immediate)
                smoke.check("the log page opens, newest first", log !== null && log.shown.length === p.logEntries.length
                            && log.shown[0].time >= log.shown[log.shown.length - 1].time)
                log.problemsOnly = true
                smoke.check("'Problems only' shows just the warnings and errors",
                            log.shown.length === log.problemCount && log.problemCount >= 3
                            && log.shown.every(function(e) { return e.level !== "INFO" }))
                log.problemsOnly = false
                ticker.waited = 0
                break
            case 7:
                // Give Silica a moment to build the long list's quick-scroll handle:
                // leaving within milliseconds trips a race inside Silica itself.
                if (++ticker.waited < 10) { smoke.step--; break }
                stack.pop(null, PageStackAction.Immediate)
                var about = stack.push(Qt.resolvedUrl("pages/AboutPage.qml"), {}, PageStackAction.Immediate)
                smoke.check("About: made by Valatalo", about.author === "Valatalo")
                stack.pop(null, PageStackAction.Immediate)
                smoke.finish()
                break
            }
        }
    }
}
