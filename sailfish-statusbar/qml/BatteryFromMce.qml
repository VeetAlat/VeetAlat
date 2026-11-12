// StatusBar's battery, from MCE (the phone's power manager): the level,
// whether it's charging, low, and power save mode.
import QtQuick 2.6
import Nemo.Mce 1.0

Item {
    visible: false

    readonly property bool ok: level.valid && level.percent >= 0
    readonly property int percent: level.valid ? level.percent : -1
    readonly property bool charging: batteryState.value === MceBatteryState.Charging
                                     || (charger.valid && charger.charging)
    readonly property bool low: batteryStatus.valid && (batteryStatus.status === MceBatteryStatus.Low
                                                        || batteryStatus.status === MceBatteryStatus.Empty)
    readonly property bool powerSave: powerSaveMode.valid && powerSaveMode.active

    MceBatteryLevel { id: level }
    MceBatteryState { id: batteryState }
    MceBatteryStatus { id: batteryStatus }
    MceChargerState { id: charger }
    McePowerSaveMode { id: powerSaveMode }
}
