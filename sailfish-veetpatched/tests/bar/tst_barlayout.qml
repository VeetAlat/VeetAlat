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

        function layout(c, file) {
            loader.source = ""
            loader.width = c.screen
            loader.fake = { corner: c.corner, battery: c.battery, left: c.left, right: c.right }
            loader.setSource(file || "NotchStatusBar.qml", { notchX: c.x, notchWidth: c.w, notchHeight: 40, upright: true })
            verify(loader.item !== null, "the bar loads")
            // The SDK loads no fonts here (every glyph is a square box), so
            // the clock is given the width "23:59", the widest time of day,
            // has in Sail Sans at Theme.fontSizeSmall on the phone.
            var clock = clockOf(loader.item)
            clock.width = Math.round(2.5 * Theme.fontSizeSmall)
            return loader.item
        }
        // Left and right edges of an item as drawn (scale included), in the bar.
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
                { tag: "wide notch, all icons",       screen: 560, x: 190, w: 180, corner: 40, battery: 46, left: 3, right: 5, shrinks: true },
                { tag: "wide notch, few icons",       screen: 560, x: 200, w: 160, corner: 40, battery: 34,  left: 0, right: 3, shrinks: false },
                { tag: "very wide notch",             screen: 560, x: 150, w: 260, corner: 40, battery: 46, left: 3, right: 5, shrinks: true },
                { tag: "notch left of centre",        screen: 560, x: 220, w: 60,  corner: 40, battery: 46, left: 2, right: 4, shrinks: true }
            ]
        }

        function test_layout(c) {
            var bar = layout(c)
            verify(bar.visible, "the bar shows")
            verify(bar.leftRow !== null && bar.rightRow !== null, "it finds both rows of icons")
            compare(bar.leftRow.objectName, "leftIndicators")
            compare(bar.rightRow.objectName, "rightIndicators")
            var clock = clockOf(bar)
            verify(clock !== null && clock.width > 0, "the clock is there")
            var compact = find(bar, "compactBattery")
            tryCompare(compact, "status", Loader.Ready)
            verify(bar.compactBattery && compact.visible, "the compact battery takes the original's place")
            verify(!find(bar, "battery").visible, "the home screen's battery is hidden in the bar")
            compact.item.percent = 100
            compare(find(compact.item, "percent").text, "100")
            compact.item.percent = -1
            compare(find(compact.item, "percent").text, "", "no number while the charge is unknown")
            compact.item.percent = 57
            // The home screen's: an icon, a gap and "100%" (about two em).
            var original = Theme.iconSizeExtraSmall + Theme.paddingSmall + 2 * Theme.fontSizeSmall
            verify(compact.width < original / 2, "it's under half the width of the original (" + compact.width + " vs " + original + ")")
            var k = box(bar, clock), b = box(bar, compact), l = box(bar, bar.leftRow), r = box(bar, bar.rightRow)
            // A Row sizes itself on the next frame, and none is drawn here:
            // its edges come from the icons the bar adds up instead.
            l.right = l.left + bar.leftRowWidth * bar.leftScale
            r.left = r.right - bar.rowWidth(bar.rightRow) * bar.rightScale
            var notchRight = c.x + c.w
            console.log("GEOM " + c.tag + "|" + c.screen + "|" + c.x + "|" + c.w + "|" + bar.edge
                        + "|clock " + k.left + " " + k.right + " " + k.top + " " + k.bottom
                        + "|left " + l.left + " " + l.right + " " + l.top + " " + l.bottom
                        + "|right " + r.left + " " + r.right + " " + r.top + " " + r.bottom
                        + "|" + bar.leftScale.toFixed(2) + "|" + bar.rightScale.toFixed(2))
            verify(k.left >= bar.edge - 0.5, "the clock starts clear of the rounded corner")
            verify(k.right <= b.left + 0.5, "the clock and the battery don't overlap (" + k.right + " > " + b.left + ")")
            verify(b.right <= c.x + 0.5 || bar.leftScale === bar.minScale, "the battery is before the notch")
            if (c.left > 0) {
                verify(b.right <= l.left + 0.5, "the battery and the other left icons don't overlap (" + b.right + " > " + l.left + ")")
                verify(l.right <= c.x + 0.5 || bar.leftScale === bar.minScale, "the left icons stop before the notch (" + l.right + " > " + c.x + ")")
            }
            verify(r.left >= notchRight - 0.5 || bar.rightScale === bar.minScale, "the right icons start after the notch")
            verify(r.right <= c.screen - bar.edge + 0.5, "the right icons stay clear of the corner")
            compare(bar.leftScale < 1, c.shrinks, "it shrinks the left side only when it has to")
            // Centred vertically in the bar.
            fuzzyCompare((k.top + k.bottom) / 2, bar.height / 2, 1.5)
            fuzzyCompare((b.top + b.bottom) / 2, bar.height / 2, 1.5)
            if (c.left > 0) fuzzyCompare((l.top + l.bottom) / 2, bar.height / 2, 1.5)
        }

        function test_battery_states() {
            var bar = layout({ screen: 560, x: 265, w: 30, corner: 24, battery: 34, left: 1, right: 3 })
            var compact = find(bar, "compactBattery")
            tryCompare(compact, "status", Loader.Ready)
            var b = compact.item
            b.charging = false; b.low = false; b.powerSave = false
            verify(Qt.colorEqual(b.fillColor, Qt.rgba(1, 1, 1, 0.35)), "normally a light fill")
            b.powerSave = true
            verify(Qt.colorEqual(b.fillColor, "#c98a00"), "amber in power save")
            b.low = true
            verify(Qt.colorEqual(b.fillColor, "#d93030"), "red when low")
            b.charging = true
            verify(Qt.colorEqual(b.fillColor, "#2e9e4f"), "green while charging, whatever else")
        }

        function test_broken_compact_battery() {
            // If CompactBattery.qml can't load, the home screen's battery stays.
            var bar = layout({ screen: 560, x: 265, w: 30, corner: 24, battery: 34, left: 1, right: 3 }, "broken/NotchStatusBar.qml")
            var compact = find(bar, "compactBattery")
            tryCompare(compact, "status", Loader.Error)
            verify(!bar.compactBattery)
            verify(find(bar, "battery").visible, "the original battery is shown")
            var k = box(bar, clockOf(bar)), l = box(bar, bar.leftRow)
            verify(k.right <= l.left + 0.5, "and the clock still doesn't overlap it")
        }

        function test_fallback_without_rows() {
            // A Sailfish version whose status area is built differently: no
            // rows found, the clock goes just left of the notch as before.
            var bar = layout({ screen: 560, x: 265, w: 30, corner: 24, battery: 34, left: 0, right: 0 })
            bar.leftRow = null
            bar.rightRow = null
            bar.originalBattery = null
            var clock = clockOf(bar)
            compare(bar.leftScale, 1)
            var k = box(bar, clock)
            verify(k.right <= 265, "the clock is left of the notch")
            compare(find(bar, "compactBattery").status, Loader.Null, "no compact battery without the home screen's to replace")
        }
    }
}
