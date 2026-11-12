/*
 * StatusBar, a VeetPatched patch for Sailfish OS: a black bar over the
 * screen's notch while an app is open, showing the time, the battery and
 * the status icons, like Android apps get.
 *
 * Left of the notch is all StatusBar's own: the clock and a compact
 * battery (the percentage inside it), shrunk to fit if needed. Right of
 * the notch, the home screen's own status icons show through a window cut
 * to that side, so its left icons (its battery and percentage) are left
 * out without depending on how a Sailfish version builds them. If no
 * battery source works, the home screen's whole status area shows instead.
 *
 * Loaded by the patched AppLayer.qml into the app layer's overlay, so it
 * sits above the app and moves with it when you swipe to peek. Shown only
 * with the phone upright (that's where the notch is on top). Loaded
 * through a Loader: if it fails on some Sailfish version, there's just no
 * bar, and apps work as without the patch.
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

    // Where the battery's numbers come from: the first of these that loads
    // and gives a charge within sourceTimeout. Tests set their own.
    property var batterySources: ["BatteryFromMce.qml", "BatteryFromIndicator.qml", "BatteryFromSettings.qml"]
    property int sourceTimeout: 4000
    property int sourceIndex: 0
    property bool sourceChosen: false
    property var sourcesTried: []
    // "ok", "trying", or "none": no source works, so the home screen's own
    // battery shows (its whole status area, as before).
    readonly property string batteryState: sourceChosen ? "ok" : sourceIndex >= batterySources.length ? "none" : "trying"

    function sourceName(i) { return String(batterySources[i]).replace(/^BatteryFrom/, "").replace(/\.qml$/, "") }
    function nextSource(why) {
        var tried = sourcesTried.slice()
        tried.push(sourceName(sourceIndex) + " " + why)
        sourcesTried = tried
        sourceIndex++
    }
    function checkSource() {
        if (!sourceChosen && batterySource.status === Loader.Ready && batterySource.item && batterySource.item.ok) {
            sourceWait.stop()
            sourceChosen = true
        }
    }

    // The home screen's right-hand icons, found once it's built (on
    // Sailfish 4.6, a Row anchored right): shrunk if they'd reach the notch.
    property Item rightRow: null

    // Room each side of the notch. A side that doesn't fit is shrunk to
    // fit, but no smaller than minScale.
    readonly property real minScale: 0.6
    readonly property real edge: statusArea.cornerPadding > 0 ? statusArea.cornerPadding : Theme.paddingLarge
    readonly property real gap: Theme.paddingMedium
    readonly property real leftRoom: notchX - gap - edge
    readonly property real leftNeeded: leftGroup.width
    readonly property real leftScale: batteryState === "none" ? 1 : fit(leftRoom, leftNeeded)
    readonly property real rightRoom: width - edge - (notchX + notchWidth + gap)
    readonly property real rightScale: rightRow && batteryState !== "none" ? fit(rightRoom, rowWidth(rightRow)) : 1

    function fit(room, needed) {
        return needed <= 0 || needed <= room ? 1 : Math.max(minScale, room / needed)
    }
    // Added up here: a Row only updates its own width on the next frame.
    function rowWidth(row) {
        var w = 0, n = 0
        for (var i = 0; i < row.children.length; i++) {
            var c = row.children[i]
            if (c.visible && c.width > 0) { w += c.width; n++ }
        }
        return w + Math.max(0, n - 1) * row.spacing
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
        var rows = rowsOf(statusArea, 2, [])
        if (rows.length >= 2) {
            rows.sort(function(a, b) { return a.x - b.x })
            rightRow = rows[rows.length - 1]
        }
        report.start()
    }

    // One line in the home screen's journal, which VeetPatched copies into
    // its log (a warning, so it isn't filtered out like debug output).
    readonly property string startedAt: Qt.formatTime(new Date(), "hh:mm:ss")
    Timer {
        id: report
        interval: 8000
        onTriggered: console.warn("VeetPatched StatusBar: screen " + bar.width + ", notch " + bar.notchX + "+" + bar.notchWidth
                                  + "x" + bar.notchHeight
                                  + ", battery " + (bar.batteryState === "ok" ? "from " + bar.sourceName(bar.sourceIndex)
                                                    : bar.batteryState === "none" ? "the home screen's" : "still looking")
                                  + (bar.sourcesTried.length ? " (tried: " + bar.sourcesTried.join(", ") + ")" : "")
                                  + "; left: room " + Math.round(bar.leftRoom) + ", needs " + Math.round(bar.leftNeeded)
                                  + ", scale " + bar.leftScale.toFixed(2)
                                  + "; right icons " + (bar.rightRow ? "found, room " + Math.round(bar.rightRoom)
                                                       + ", need " + Math.round(bar.rowWidth(bar.rightRow)) : "not found")
                                  + ", scale " + bar.rightScale.toFixed(2)
                                  + " (started " + bar.startedAt + ")")
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
    }

    // The battery's numbers. A file that fails to load, or gives no charge
    // in time, is skipped for the next.
    Loader {
        id: batterySource
        source: bar.sourceIndex < bar.batterySources.length ? bar.batterySources[bar.sourceIndex] : ""
        onStatusChanged: if (batterySource.status === Loader.Error) bar.nextSource("failed to load")
        onLoaded: {
            sourceWait.restart()
            bar.checkSource()
        }
    }
    Connections {
        target: batterySource.item
        ignoreUnknownSignals: true
        onOkChanged: bar.checkSource()
    }
    Timer {
        id: sourceWait
        interval: bar.sourceTimeout
        onTriggered: if (!bar.sourceChosen) bar.nextSource("gave no charge")
    }

    // The home screen's status icons, seen through a window right of the
    // notch (all of them if there's no battery of ours). In lock screen
    // mode it leaves out its own clock, which would go below the notch.
    Item {
        id: statusWindow
        objectName: "statusWindow"
        x: bar.batteryState === "none" ? 0 : Math.round(bar.notchX + bar.notchWidth + bar.gap)
        width: bar.width - x
        height: bar.height
        clip: true

        StatusArea {
            id: statusArea

            x: -statusWindow.x
            width: bar.width
            // Its icon row is as tall as the battery; its height adds the notch.
            y: Math.round((bar.height - (statusArea.height - bar.notchHeight)) / 2)
            color: "white"
            lockscreenMode: true
            updatesEnabled: bar.visible
        }
    }

    // Kept clear of the notch, shrunk from the right edge if needed.
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

    // The clock and the battery, at the left edge like Android. Placed by
    // bindings rather than a Row, so it's right at once, without waiting
    // for a frame to be drawn.
    Item {
        id: leftGroup

        x: bar.batteryState !== "none" ? bar.edge
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

        CompactBattery {
            id: battery

            objectName: "compactBattery"
            x: clock.width + bar.gap
            anchors.verticalCenter: parent.verticalCenter
            visible: bar.batteryState === "ok"
            source: bar.batteryState === "ok" ? batterySource.item : null
        }
    }
}
