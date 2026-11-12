import QtQuick 2.6
import QtTest 1.0
import Sailfish.Silica 1.0

// Lays out the real StatusArea bar (NotchStatusBar.qml) over notches of
// different sizes and checks that the clock, the left icons and the right
// icons never overlap each other or the notch.
Item {
    id: root
    width: 560
    height: 200

    // The app layer with an app open.
    Item { id: host; property var window: ({}) }

    Loader {
        id: loader
        property Item hostLayer: host
        property var fake: ({})
        width: root.width
    }

    TestCase {
        name: "BarLayout"

        function layout(c, sources, file) {
            loader.source = ""
            loader.width = c.screen
            loader.fake = { corner: c.corner, battery: c.battery, left: c.left, right: c.right }
            loader.setSource(file || "NotchStatusBar.qml", { notchX: c.x, notchWidth: c.w, notchHeight: 40, upright: true,
                                                            batterySources: sources || ["FakeBattery.qml"], sourceTimeout: 300 })
            verify(loader.item !== null, "the bar loads")
            // The SDK loads no fonts here (every glyph is a square box), so
            // the clock is given the width "23:59", the widest time of day,
            // has in Sail Sans at Theme.fontSizeSmall on the phone.
            clockOf(loader.item).width = Math.round(2.5 * Theme.fontSizeSmall)
            return loader.item
        }
        // An item's edges as drawn (scales included), in the bar.
        function box(bar, item) {
            var p = item.mapToItem(bar, 0, 0), q = item.mapToItem(bar, item.width, item.height)
            return { left: p.x, right: q.x, top: p.y, bottom: q.y }
        }
        function find(item, name) {
            if (item.objectName === name) return item
            var kids = item.children || []
            for (var i = 0; i < kids.length; i++) {
                var f = find(kids[i], name)
                if (f) return f
            }
            return null
        }
        function clockOf(bar) { return find(bar, "clock") }

        function test_layout_data() {
            return [
                { tag: "small punch hole, few icons", screen: 560, x: 265, w: 30,  corner: 24, battery: 34,  left: 1, right: 3, shrinks: false },
                { tag: "wide notch, all icons",       screen: 560, x: 190, w: 180, corner: 40, battery: 46, left: 3, right: 5, shrinks: false },
                { tag: "wide notch, few icons",       screen: 560, x: 200, w: 160, corner: 40, battery: 34,  left: 0, right: 3, shrinks: false },
                { tag: "very wide notch",             screen: 560, x: 150, w: 260, corner: 40, battery: 46, left: 3, right: 5, shrinks: true },
                { tag: "notch left of centre",        screen: 560, x: 160, w: 60,  corner: 40, battery: 46, left: 2, right: 4, shrinks: true }
            ]
        }

        function test_layout(c) {
            var bar = layout(c)
            verify(bar.visible, "the bar shows")
            tryCompare(bar, "batteryState", "ok")
            var clock = clockOf(bar), battery = find(bar, "compactBattery"), win = find(bar, "statusWindow")
            verify(battery.visible, "our battery shows")
            compare(find(battery, "percent").text, "57", "with the source's charge")
            var k = box(bar, clock), b = box(bar, battery)
            var homeLeft = find(bar, "leftIndicators"), homeRight = find(bar, "rightIndicators")
            var hl = box(bar, homeLeft), hr = box(bar, homeRight)
            // A Row sizes itself on the next frame, and none is drawn here.
            hl.right = hl.left + bar.rowWidth(homeLeft) * homeLeft.scale
            hr.left = hr.right - bar.rowWidth(homeRight) * bar.rightScale
            var notchRight = c.x + c.w
            console.log("GEOM " + c.tag + "|clock " + k.left + "-" + k.right + "|battery " + b.left + "-" + b.right
                        + "|window " + win.x + "|home left " + hl.left + "-" + hl.right + "|home right " + hr.left + "-" + hr.right
                        + "|" + bar.leftScale.toFixed(2) + "|" + bar.rightScale.toFixed(2))
            verify(k.left >= bar.edge - 0.5, "the clock starts clear of the rounded corner")
            verify(k.right <= b.left + 0.5, "the clock and the battery don't overlap (" + k.right + " > " + b.left + ")")
            verify(b.right <= c.x + 0.5 || bar.leftScale === bar.minScale, "the battery stops before the notch (" + b.right + " > " + c.x + ")")
            compare(bar.leftScale < 1, c.shrinks, "it shrinks the left side only when it has to")
            verify(win.clip && win.x >= notchRight, "the home screen's icons show only right of the notch")
            verify(hl.right <= win.x, "so its battery and left icons are hidden (" + hl.right + " > " + win.x + ")")
            verify(hr.left >= win.x - 0.5 || bar.rightScale === bar.minScale, "and its right icons show, clear of the notch")
            verify(hr.right <= c.screen - bar.edge + 0.5, "clear of the corner too")
            fuzzyCompare((k.top + k.bottom) / 2, bar.height / 2, 1.5)
            fuzzyCompare((b.top + b.bottom) / 2, bar.height / 2, 1.5)
        }

        function test_battery_states() {
            var bar = layout({ screen: 560, x: 265, w: 30, corner: 24, battery: 34, left: 1, right: 3 })
            tryCompare(bar, "batteryState", "ok")
            var b = find(bar, "compactBattery"), src = b.source
            verify(Qt.colorEqual(b.fillColor, Qt.rgba(1, 1, 1, 0.35)), "normally a light fill")
            src.powerSave = true
            verify(Qt.colorEqual(b.fillColor, "#c98a00"), "amber in power save")
            src.low = true
            verify(Qt.colorEqual(b.fillColor, "#d93030"), "red when low")
            src.charging = true
            verify(Qt.colorEqual(b.fillColor, "#2e9e4f"), "green while charging")
            src.percent = 100
            compare(find(b, "percent").text, "100")
            // The home screen's: an icon, a gap and "100%" (about two em).
            var original = Theme.iconSizeExtraSmall + Theme.paddingSmall + 2 * Theme.fontSizeSmall
            verify(b.width < original / 2, "under half the width of the home screen's (" + b.width + " vs " + original + ")")
        }

        function test_source_fallback() {
            // One that doesn't load, one that gives no charge, one that works.
            var bar = layout({ screen: 560, x: 265, w: 30, corner: 24, battery: 34, left: 1, right: 3 },
                             ["Broken.qml", "NoCharge.qml", "FakeBattery.qml"])
            compare(bar.batteryState, "trying")
            verify(find(bar, "statusWindow").x > 265, "the home screen's battery stays hidden while it looks")
            tryCompare(bar, "batteryState", "ok", 3000)
            compare(bar.sourceName(bar.sourceIndex), "FakeBattery")
            compare(bar.sourcesTried.join(", "), "Broken failed to load, NoCharge gave no charge")
        }

        function test_no_source() {
            // Nothing works: the home screen's whole status area, its battery
            // included, and the clock left of the notch, as before.
            var bar = layout({ screen: 560, x: 265, w: 30, corner: 24, battery: 34, left: 1, right: 3 },
                             ["Broken.qml", "NoCharge.qml"])
            tryCompare(bar, "batteryState", "none", 3000)
            verify(!find(bar, "compactBattery").visible, "no battery of ours")
            compare(find(bar, "statusWindow").x, 0, "the whole status area shows")
            compare(bar.leftScale, 1)
            var k = box(bar, clockOf(bar))
            verify(k.right <= 265, "the clock is left of the notch")
        }

        function test_real_sources_load() {
            // The phone's three sources compile and load here (the SDK has no
            // power manager to give a charge, so they're not ok).
            var names = ["BatteryFromMce.qml", "BatteryFromIndicator.qml", "BatteryFromSettings.qml"]
            for (var i = 0; i < names.length; i++) {
                var c = Qt.createComponent(names[i])
                compare(c.status, Component.Ready, names[i] + ": " + c.errorString())
                var o = c.createObject(root)
                verify(o !== null, names[i] + " creates")
                verify(o.hasOwnProperty("ok") && o.hasOwnProperty("percent") && o.hasOwnProperty("charging")
                       && o.hasOwnProperty("low") && o.hasOwnProperty("powerSave"), names[i] + " has everything")
                o.destroy()
            }
        }

        function test_report() {
            // The line for the journal, 8 s after start (the script checks it).
            var bar = layout({ screen: 560, x: 200, w: 160, corner: 40, battery: 34, left: 1, right: 3 },
                             ["NoCharge.qml", "FakeBattery.qml"])
            wait(8500)
            compare(bar.batteryState, "ok")
        }
    }
}
