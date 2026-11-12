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

        function layout(c) {
            loader.source = ""
            loader.width = c.screen
            loader.fake = { corner: c.corner, battery: c.battery, left: c.left, right: c.right }
            loader.setSource("NotchStatusBar.qml", { notchX: c.x, notchWidth: c.w, notchHeight: 40, upright: true })
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
            var p = item.mapToItem(bar, 0, 0)
            return { left: p.x, right: p.x + item.width * item.scale, top: p.y, bottom: p.y + item.height * item.scale }
        }
        function clockOf(bar) {
            for (var i = 0; i < bar.children.length; i++)
                if (bar.children[i].hasOwnProperty("updatesEnabled") && bar.children[i].hasOwnProperty("font")) return bar.children[i]
            return null
        }

        function test_layout_data() {
            return [
                { tag: "small punch hole, few icons", screen: 560, x: 265, w: 30,  corner: 24, battery: 34,  left: 1, right: 3, shrinks: false },
                { tag: "wide notch, all icons",       screen: 560, x: 190, w: 180, corner: 40, battery: 46, left: 3, right: 5, shrinks: true },
                { tag: "wide notch, few icons",       screen: 560, x: 200, w: 160, corner: 40, battery: 34,  left: 0, right: 3, shrinks: false },
                { tag: "very wide notch",             screen: 560, x: 150, w: 260, corner: 40, battery: 46, left: 3, right: 5, shrinks: true },
                { tag: "notch left of centre",        screen: 560, x: 230, w: 60,  corner: 40, battery: 46, left: 2, right: 4, shrinks: true }
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
            var k = box(bar, clock), l = box(bar, bar.leftRow), r = box(bar, bar.rightRow)
            var notchRight = c.x + c.w
            console.log("GEOM " + c.tag + "|" + c.screen + "|" + c.x + "|" + c.w + "|" + bar.edge
                        + "|clock " + k.left + " " + k.right + " " + k.top + " " + k.bottom
                        + "|left " + l.left + " " + l.right + " " + l.top + " " + l.bottom
                        + "|right " + r.left + " " + r.right + " " + r.top + " " + r.bottom
                        + "|" + bar.leftScale.toFixed(2) + "|" + bar.rightScale.toFixed(2))
            verify(k.left >= bar.edge - 0.5, "the clock starts clear of the rounded corner")
            verify(k.right <= l.left + 0.5, "the clock and the battery don't overlap (" + k.right + " > " + l.left + ")")
            verify(l.right <= c.x + 0.5 || bar.leftScale === bar.minScale, "the left icons stop before the notch (" + l.right + " > " + c.x + ")")
            verify(r.left >= notchRight - 0.5 || bar.rightScale === bar.minScale, "the right icons start after the notch")
            verify(r.right <= c.screen - bar.edge + 0.5, "the right icons stay clear of the corner")
            compare(bar.leftScale < 1, c.shrinks, "it shrinks the left side only when it has to")
            // Centred vertically in the bar.
            fuzzyCompare((k.top + k.bottom) / 2, bar.height / 2, 1.5)
            fuzzyCompare((l.top + l.bottom) / 2, bar.height / 2, 1.5)
        }

        function test_fallback_without_rows() {
            // A Sailfish version whose status area is built differently: no
            // rows found, the clock goes just left of the notch as before.
            var bar = layout({ screen: 560, x: 265, w: 30, corner: 24, battery: 34, left: 0, right: 0 })
            bar.leftRow = null
            bar.rightRow = null
            var clock = clockOf(bar)
            compare(bar.leftScale, 1)
            verify(clock.x + clock.width <= 265, "the clock is left of the notch")
        }
    }
}
