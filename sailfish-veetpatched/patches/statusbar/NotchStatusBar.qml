/*
 * StatusBar, a VeetPatched patch for Sailfish OS: a black bar over the
 * screen's notch while an app is open, showing the time and the status
 * icons the home screen shows, like Android apps get.
 *
 * Loaded by the patched AppLayer.qml into the app layer's overlay, so it
 * sits above the app and moves with it when you swipe to peek. Shown only
 * with the phone upright (that's where the notch is on top); turned
 * sideways, apps get the whole screen as before.
 *
 * This file is loaded through a Loader: if it fails on some Sailfish
 * version, there's just no bar, and apps work as without the patch.
 */
import QtQuick 2.6
import Sailfish.Silica 1.0
import Sailfish.Lipstick 1.0
import org.nemomobile.lipstick 0.1
import com.jolla.lipstick 0.1
import "file:///usr/share/lipstick-jolla-home-qt5/statusarea"

Item {
    id: bar

    // The app layer, from the Loader in AppLayer.qml.
    readonly property Item hostLayer: parent ? parent.hostLayer : null
    property bool upright: Lipstick.compositor ? Lipstick.compositor.topmostWindowOrientation === Qt.PortraitOrientation : false

    // Where the notch is (tests set these).
    property real notchX: Screen.hasCutouts ? Screen.topCutout.x : 0
    property real notchWidth: Screen.hasCutouts ? Screen.topCutout.width : 0
    property real notchHeight: Screen.hasCutouts ? Screen.topCutout.height : 0

    // The status area's two rows of icons, found once it's built: on the
    // left battery, profile, do not disturb and alarm; on the right location,
    // VPN, Bluetooth, Wi-Fi and mobile signal. Null if a Sailfish version
    // builds it differently; then the clock just goes left of the notch.
    property Item leftRow: null
    property Item rightRow: null
    // Its battery, hidden here: ours shows the percentage inside a smaller one.
    property Item originalBattery: null
    readonly property bool compactBattery: originalBattery !== null && battery.status === Loader.Ready

    // Room on each side of the notch, and how much of it is needed. When a
    // side doesn't fit, it's shrunk to fit, but no smaller than minScale.
    readonly property real minScale: 0.6
    readonly property real edge: status.cornerPadding
    readonly property real gap: Theme.paddingMedium
    readonly property real leftRoom: notchX - gap - edge
    // Added up here: a Row only updates its own width on the next frame.
    readonly property real leftRowWidth: leftRow ? rowWidth(leftRow) : 0
    readonly property real leftNeeded: leftGroup.width + (leftRowWidth > 0 ? Theme.paddingSmall + leftRowWidth : 0)
    readonly property real leftScale: leftRow ? fit(leftRoom, leftNeeded) : 1
    readonly property real rightRoom: width - edge - (notchX + notchWidth + gap)
    readonly property real rightScale: rightRow ? fit(rightRoom, rowWidth(rightRow)) : 1

    function rowWidth(row) {
        var w = 0, n = 0
        for (var i = 0; i < row.children.length; i++) {
            var c = row.children[i]
            if (c.visible && c.width > 0) { w += c.width; n++ }
        }
        return w + Math.max(0, n - 1) * row.spacing
    }

    function fit(room, needed) {
        return needed <= 0 || needed <= room ? 1 : Math.max(minScale, room / needed)
    }

    function rowsOf(item, depth, found) {
        var kids = item.children || []
        for (var i = 0; i < kids.length; i++) {
            var k = kids[i]
            if (k.hasOwnProperty("layoutDirection") && k.hasOwnProperty("spacing") && !k.hasOwnProperty("columns"))
                found.push(k)
            else if (depth > 0)
                rowsOf(k, depth - 1, found)
        }
        return found
    }

    width: parent ? parent.width : 0
    height: notchHeight
    visible: notchHeight > 0 && upright && hostLayer !== null && hostLayer.window !== null && hostLayer.window !== undefined

    Component.onCompleted: {
        var rows = rowsOf(status, 2, [])
        if (rows.length >= 2) {
            rows.sort(function(a, b) { return a.x - b.x })
            leftRow = rows[0]
            rightRow = rows[rows.length - 1]
            var icons = leftRow.children
            for (var i = 0; i < icons.length; i++) {
                var c = icons[i]
                if (c.hasOwnProperty("text") && (c.hasOwnProperty("isCharging") || c.hasOwnProperty("usbPreparingMode")))
                    originalBattery = c
            }
        }
        report.start()
    }

    // One line in the home screen's journal, which VeetPatched copies into
    // its log (a warning, so it isn't filtered out like debug output).
    readonly property string startedAt: Qt.formatTime(new Date(), "hh:mm:ss")
    function describe(item) {
        if (!item) return "none"
        var kids = []
        for (var i = 0; i < item.children.length; i++)
            kids.push(String(item.children[i]).replace(/_QMLTYPE_\d+|_QML_\d+|\(0x[0-9a-f]+\)/g, ""))
        return kids.join(" ")
    }
    Timer {
        id: report
        interval: 3000
        onTriggered: console.warn("VeetPatched StatusBar: screen " + bar.width + ", notch " + bar.notchX + "+" + bar.notchWidth
                                  + "x" + bar.notchHeight
                                  + ", icon rows " + (bar.leftRow ? "found" : "not found")
                                  + ", battery " + (bar.compactBattery ? "compact"
                                                    : bar.originalBattery ? "the home screen's (compact one: " + ["off", "loaded", "loading", "failed"][battery.status] + ")"
                                                    : "the home screen's (not found among: " + bar.describe(bar.leftRow) + ")")
                                  + "; left: room " + Math.round(bar.leftRoom) + ", needs " + Math.round(bar.leftNeeded)
                                  + ", scale " + bar.leftScale.toFixed(2)
                                  + "; right: room " + Math.round(bar.rightRoom) + ", needs " + (bar.rightRow ? Math.round(bar.rowWidth(bar.rightRow)) : 0)
                                  + ", scale " + bar.rightScale.toFixed(2)
                                  + " (started " + bar.startedAt + ")")
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
    }

    // The home screen's own status icons. In lock screen mode it leaves out
    // its own clock, which would go below the notch; ours goes in the bar.
    StatusArea {
        id: status

        // Its icon row is as tall as the battery; its height adds the notch.
        y: Math.round((bar.height - (status.height - bar.notchHeight)) / 2)
        color: "white"
        lockscreenMode: true
        updatesEnabled: bar.visible
    }

    // The clock and our battery first, at the left edge like Android, then
    // the rest of the left icons.
    Binding {
        target: bar.leftRow
        when: bar.leftRow !== null
        property: "x"
        value: Math.round(bar.edge + (leftGroup.width + Theme.paddingSmall) * bar.leftScale)
    }
    Binding {
        target: bar.originalBattery
        when: bar.compactBattery
        property: "visible"
        value: false
    }
    Binding {
        target: bar.leftRow
        when: bar.leftRow !== null
        property: "transformOrigin"
        value: Item.Left
    }
    Binding {
        target: bar.leftRow
        when: bar.leftRow !== null
        property: "scale"
        value: bar.leftScale
    }
    // The right icons keep to the right edge, shrunk from there if needed.
    Binding {
        target: bar.rightRow
        when: bar.rightRow !== null
        property: "transformOrigin"
        value: Item.Right
    }
    Binding {
        target: bar.rightRow
        when: bar.rightRow !== null
        property: "scale"
        value: bar.rightScale
    }

    // Placed by bindings rather than a Row, so it's right at once, without
    // waiting for a frame to be drawn.
    Item {
        id: leftGroup

        x: bar.leftRow ? bar.edge
                       : bar.notchX > leftGroup.width + 2 * Theme.paddingLarge
                         ? bar.notchX - leftGroup.width - Theme.paddingLarge
                         : Theme.paddingLarge
        anchors.verticalCenter: parent.verticalCenter
        width: clock.width + (battery.visible ? bar.gap + battery.width : 0)
        height: Math.max(clock.height, battery.height)
        transformOrigin: Item.Left
        scale: bar.leftScale

        ClockItem {
            id: clock

            objectName: "clock"
            anchors.verticalCenter: parent.verticalCenter
            updatesEnabled: bar.visible
            color: "white"
            font { pixelSize: Theme.fontSizeSmall; family: Theme.fontFamilyHeading }

            Connections {
                target: Lipstick.compositor
                onDisplayAboutToBeOn: clock.forceUpdate()
            }
        }

        Loader {
            id: battery

            objectName: "compactBattery"
            x: clock.width + bar.gap
            anchors.verticalCenter: parent.verticalCenter
            active: bar.originalBattery !== null
            visible: battery.status === Loader.Ready   // "status" alone would be the StatusArea's id
            source: "CompactBattery.qml"
            onLoaded: item.original = Qt.binding(function() { return bar.originalBattery })
        }
    }
}
