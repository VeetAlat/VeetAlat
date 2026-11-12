/*
 * StatusBar's battery: the charge percentage inside a small battery, in
 * place of the home screen's battery icon with the percentage beside it,
 * so the clock has room left of the notch.
 *
 * The fill shows the charge: green while charging, red when low, amber in
 * power save mode, white otherwise. Everything comes from the home
 * screen's own battery indicator (hidden in the bar), so there's nothing
 * here that a Sailfish update could move. Loaded through a Loader: if it
 * fails, the home screen's own battery stays instead.
 */
import QtQuick 2.6
import Sailfish.Silica 1.0

Item {
    id: battery

    // The home screen's BatteryStatusIndicator: its text is "57%", and its
    // icon is icon-status-charge, -battery-warning, -powersave or -battery.
    property Item original
    readonly property string iconName: original && original.icon ? String(original.icon) : ""

    property int percent: {
        var n = original ? parseInt(original.text, 10) : NaN
        return isNaN(n) ? -1 : n
    }
    property bool charging: original ? original.isCharging === true || iconName.indexOf("icon-status-charge") >= 0 : false
    property bool low: iconName.indexOf("battery-warning") >= 0
    property bool powerSave: iconName.indexOf("powersave") >= 0
    property color color: "white"

    readonly property real line: Math.max(1, Math.round(Theme.pixelRatio * 1.5))
    readonly property color fillColor: charging ? "#2e9e4f"
                                     : low ? "#d93030"
                                     : powerSave ? "#c98a00"
                                     : Qt.rgba(1, 1, 1, 0.35)

    height: Math.round(Theme.iconSizeExtraSmall * 0.75)
    width: body.width + nub.width

    Rectangle {
        id: body

        width: Math.round(battery.height * 1.9)
        height: battery.height
        radius: Math.round(height / 4)
        color: "transparent"
        border { width: battery.line; color: battery.color }

        // The charge, from the left.
        Rectangle {
            x: 2 * battery.line
            y: 2 * battery.line
            height: parent.height - 4 * battery.line
            width: Math.max(0, Math.min(100, battery.percent)) / 100 * (parent.width - 4 * battery.line)
            radius: Math.max(0, parent.radius - 2 * battery.line)
            color: battery.fillColor
            visible: battery.percent > 0
        }

        Text {
            objectName: "percent"
            anchors.centerIn: parent
            color: battery.color
            font { pixelSize: Math.round(battery.height * 0.72); bold: true; family: Theme.fontFamilyHeading }
            text: battery.percent < 0 ? "" : String(battery.percent)
        }
    }

    // The battery's terminal.
    Rectangle {
        id: nub
        anchors { left: body.right; verticalCenter: body.verticalCenter }
        width: Math.max(2, Math.round(battery.line * 1.5))
        height: Math.round(body.height * 0.4)
        radius: width / 2
        color: battery.color
    }
}
