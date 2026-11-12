// StatusBar's battery, from a hidden copy of Sailfish's own battery
// indicator: its text is "57%", its icon icon-status-charge, -battery-warning,
// -powersave or -battery.
import QtQuick 2.6
import Sailfish.Lipstick 1.0

Item {
    visible: false

    readonly property int percent: {
        var n = parseInt(indicator.text, 10)
        return isNaN(n) ? -1 : n
    }
    readonly property string iconName: indicator.icon ? String(indicator.icon) : ""
    readonly property bool ok: percent >= 0
    readonly property bool charging: indicator.isCharging === true || iconName.indexOf("icon-status-charge") >= 0
    readonly property bool low: iconName.indexOf("battery-warning") >= 0
    readonly property bool powerSave: iconName.indexOf("powersave") >= 0

    BatteryStatusIndicator { id: indicator }
}
