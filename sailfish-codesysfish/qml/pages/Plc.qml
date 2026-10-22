import QtQuick 2.0
import "../js/st.js" as St
import "../js/store.js" as Store

// The PLC: compiles a project, runs it one cycle every cycleMs, and keeps
// its own clock. PLC time runs while it runs and stands still while it's
// stopped, and a step is exactly one cycle time, so timers behave like on
// a real PLC (and don't jump when the phone wakes up: a gap counts as at
// most a second). There is one, created in the main QML file as "plc".
QtObject {
    id: plc

    property var runtime: null
    property var app: null
    property int projectId: -1
    property string projectName: ""
    property string mainName: ""

    property bool running: false
    property int cycleMs: 20
    property int cycles: 0
    property real plcTime: 0          // ms
    property var error: null          // { line, message } of the last runtime error
    readonly property bool loaded: runtime !== null
    property int revision: 0          // bumped after cycles, so views refresh

    property real _lastTick: 0

    // Compiles source: { ok, errors, warnings } (and loads nothing).
    function build(source) {
        return St.compile(source)
    }

    // Compiles and loads a project, stopped: "" or the first error.
    function load(id, name, source) {
        var result = St.compile(source)
        if (!result.ok) return result.errors[0].message
        stop()
        app = result.app
        runtime = St.createRuntime(result.app)
        projectId = id
        projectName = name
        mainName = result.app.main.name
        plcTime = 0
        cycles = 0
        error = null
        revision++
        return ""
    }

    function unload() {
        stop()
        runtime = null
        app = null
        projectId = -1
        projectName = ""
        mainName = ""
        error = null
        revision++
    }

    function start() {
        if (!runtime) return
        error = null
        _lastTick = Date.now()
        running = true
    }

    function stop() {
        running = false
    }

    // One cycle while stopped.
    function step() {
        if (!runtime) return
        error = null
        _cycle(cycleMs)
        revision++
    }

    // Every variable back to its initial value, PLC time to 0.
    function reset() {
        if (!runtime) return
        runtime.reset()
        plcTime = 0
        cycles = 0
        error = null
        revision++
    }

    function setCycleMs(ms) {
        cycleMs = ms
        try { Store.setSetting("cycleMs", ms) } catch (e) { }
    }

    function _cycle(elapsed) {
        plcTime += elapsed
        var e = runtime.cycle(plcTime)
        cycles = runtime.cycles
        if (e) {
            error = e
            running = false
        }
    }

    property Timer _timer: Timer {
        interval: plc.cycleMs
        repeat: true
        running: plc.running
        onTriggered: {
            var now = Date.now()
            var elapsed = Math.min(1000, Math.max(0, now - plc._lastTick))
            plc._lastTick = now
            plc._cycle(elapsed)
        }
    }

    // Views refresh four times a second, not every cycle.
    property Timer _refresh: Timer {
        interval: 250
        repeat: true
        running: plc.running
        onTriggered: plc.revision++
    }

    Component.onCompleted: {
        try { cycleMs = parseInt(Store.setting("cycleMs", "20"), 10) || 20 } catch (e) { }
    }
}
