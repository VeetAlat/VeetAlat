// StatusBar's battery, from the system settings' battery status.
import QtQuick 2.6
import org.nemomobile.systemsettings 1.0

Item {
    visible: false

    readonly property int percent: battery.chargePercentage
    readonly property bool ok: percent >= 0
    readonly property bool charging: battery.chargerStatus === BatteryStatus.Connected
    readonly property bool low: battery.status === BatteryStatus.Low || battery.status === BatteryStatus.Empty
    readonly property bool powerSave: false

    BatteryStatus { id: battery }
}
