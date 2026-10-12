import QtQuick 2.0

// Scripted walkthrough of the real Sailvisor pages (with stub Silica + fake crosvm).
Item {
    id: driver
    property var win
    property int step: 0
    property int failures: 0
    property var page: win.pageStack.currentPage

    function ok(cond, msg) {
        if (cond) console.log("UITEST PASS " + msg)
        else { console.log("UITEST FAIL " + msg); failures++ }
    }

    function walk(item, out) {
        if (!item || out.indexOf(item) >= 0) return out
        out.push(item)
        var kids = item.children || []
        for (var i = 0; i < kids.length; i++) walk(kids[i], out)
        if (item.contentItem && item.contentItem !== item) walk(item.contentItem, out)
        return out
    }

    function click(text) {
        var all = walk(page, [])
        for (var i = 0; i < all.length; i++) {
            if (all[i].text === text && typeof all[i].clicked === "function") {
                console.log("UITEST click '" + text + "'")
                all[i].clicked()
                return true
            }
        }
        ok(false, "found clickable '" + text + "'")
        return false
    }

    function name(p) { return p ? p.toString() : "null" }

    property var steps: [
        function() { ok(page.backend.ready, "backend ready"); return 500 },
        function() { click("New test VM"); return 1500 },
        function() {
            ok(name(page).indexOf("VmPage") >= 0, "VM page opened: " + name(page))
            ok(page.cfg.name === "Test guest", "VM config loaded: " + page.cfg.name)
            ok(page.problems.length === 0, "no preflight problems: " + JSON.stringify(page.problems))
            click("Start"); return 3500
        },
        function() {
            ok(page.st.state === "running", "state running: " + page.st.state)
            ok(page.st.guest_ready === true, "guest ready")
            ok(page.consoleText.indexOf("heartbeat") >= 0, "console preview shows heartbeat")
            click("Console"); return 1500
        },
        function() {
            ok(page.text.indexOf("Hello from inside GenieZone") >= 0, "console page shows banner")
            page.send("uname -a\n"); return 1500
        },
        function() {
            ok(page.text.indexOf("guest got: uname -a") >= 0, "console input reached guest")
            win.pageStack.pop(); return 500
        },
        function() { click("Stop"); return 3500 },
        function() {
            ok(page.st.state === "stopped", "state stopped after Stop: " + page.st.state)
            ok(page.st.exit_code === 0, "exit code 0")
            click("VM log"); return 2500
        },
        function() {
            ok(page.text.indexOf("crosvm exited") >= 0, "VM log page shows exit event")
            win.pageStack.pop(); return 300
        },
        function() { click("Edit"); return 800 },
        function() {
            ok(name(page).indexOf("VmDialog") >= 0, "edit dialog opened")
            var all = walk(page, [])
            for (var i = 0; i < all.length; i++)
                if (all[i].label === "Memory" && all[i].maximumValue === 4096) all[i].value = 384
            page.accept(); return 1500
        },
        function() {
            ok(page.cfg.memory_mb === 384, "edit saved memory 384: " + page.cfg.memory_mb)
            win.pageStack.pop(); return 500
        },
        function() { click("Diagnostics"); return 3000 },
        function() {
            ok(page.checks.length > 5, "diagnostics checks: " + page.checks.length)
            click("Run boot self-test"); return 5000
        },
        function() {
            ok(page.selftest && page.selftest.finished, "self-test finished")
            ok(page.selftest && page.selftest.passed, "self-test passed: " + JSON.stringify(page.selftest))
            click("Save debug report"); return 2500
        },
        function() {
            ok(page.message.indexOf("Report saved") === 0, "report saved: " + page.message)
            win.pageStack.pop(); return 300
        },
        function() { click("New VM"); return 800 },
        function() {
            var all = walk(page, [])
            for (var i = 0; i < all.length; i++) {
                if (all[i].label === "Name") all[i].text = "Custom VM"
                if (all[i].label === "Kernel (raw arm64 Image)") all[i].text = "/nonexistent/Image"
            }
            ok(page.canAccept, "new VM dialog can accept")
            page.accept(); return 1500
        },
        function() { click("Import ISO (experimental)"); return 800 },
        function() {
            var all = walk(page, [])
            for (var i = 0; i < all.length; i++)
                if (all[i].label === "ISO file") all[i].text = "/tmp/sailvisor-ui-test.iso"
            page.inspect(); return 1500
        },
        function() {
            ok(page.detected && page.detected.profile === "Ubuntu live", "ISO detected: " + JSON.stringify(page.detected))
            page.accept(); return 3000
        },
        function() {
            ok(name(page).indexOf("MainPage") >= 0, "back on main page")
            var all = walk(page, [])
            var names = []
            for (var i = 0; i < all.length; i++) if (all[i].vmState !== undefined) names.push(all[i].name)
            var count = 0
            for (var j = 0; j < all.length; j++) if (typeof all[j].remorseAction === "function") count++
            ok(count === 4, "main list shows 4 VMs (test, selftest, custom, iso): " + count)
            ok(page.message.indexOf("Imported") === 0, "import message: " + page.message)
            ok(win.coverItem && win.coverItem.total === 4, "cover counts VMs: " + (win.coverItem ? win.coverItem.total : "none"))
            page.openVm("custom-vm"); return 1500
        },
        function() {
            ok(page.problems.length > 0, "custom VM shows problems: " + JSON.stringify(page.problems))
            click("Start"); return 1500
        },
        function() {
            ok(page.message.indexOf("kernel not found") >= 0, "start refused with message: " + page.message)
            click("Delete"); return 1500
        },
        function() {
            ok(name(page).indexOf("MainPage") >= 0, "deleted and returned to main page")
            click("App log"); return 2500
        },
        function() {
            ok(page.text.indexOf("UI backend loaded") >= 0, "app log page shows backend log")
            return 0
        }
    ]

    Timer {
        id: timer
        interval: 1500
        running: true
        onTriggered: {
            if (driver.step >= driver.steps.length) {
                console.log("UITEST DONE failures=" + driver.failures)
                Qt.quit()
                return
            }
            var wait = 0
            try {
                wait = driver.steps[driver.step]()
            } catch (e) {
                driver.ok(false, "step " + driver.step + " threw " + e)
            }
            driver.step++
            timer.interval = Math.max(50, wait || 50)
            timer.restart()
        }
    }
}
