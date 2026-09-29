import QtQuick 2.0
import QOfono 0.2

// Live view of the default modem, shared by the pages and the cover.
QtObject {
    id: network

    readonly property string modemPath: manager.defaultModem

    // Registration
    readonly property string operatorName: netreg.name
    readonly property string technology: netreg.technology
    readonly property int strength: netreg.strength
    readonly property string status: netreg.status
    readonly property string mcc: netreg.mcc
    readonly property string mnc: netreg.mnc
    readonly property int cellId: netreg.cellId

    // Radio
    readonly property string preference: radio.technologyPreference
    readonly property var availableTechnologies: radio.availableTechnologies
    readonly property bool nrCapable: radio.availableTechnologies.indexOf("nr") >= 0

    // SIM
    readonly property bool simPresent: sim.present
    readonly property string simProvider: sim.serviceProviderName
    readonly property string simMcc: sim.mobileCountryCode
    readonly property string simMnc: sim.mobileNetworkCode
    readonly property int simPinRequired: sim.pinRequired

    // Mobile data
    readonly property bool attached: connMan.attached
    readonly property string bearer: connMan.bearer
    readonly property bool dataEnabled: connMan.powered
    readonly property bool roamingAllowed: connMan.roamingAllowed
    readonly property var contexts: connMan.contexts

    // Cells
    readonly property var cells: cellMonitor.cells
    readonly property var servingCell: cellMonitor.serving
    readonly property int nrCellCount: cellMonitor.nrCellCount

    function technologyName(tech) {
        switch (tech) {
        case "nr": return "5G NR"
        case "lte": return "4G LTE"
        case "hspa": return "3G HSPA"
        case "umts": return "3G UMTS"
        case "edge": return "2G EDGE"
        case "gsm": return "2G GSM"
        default: return tech ? tech : "No service"
        }
    }

    function cellTypeName(type) { return cellMonitor.typeName(type) }
    function cellSignal(cell) { return cellMonitor.format(cell) }

    property OfonoManager manager: OfonoManager { }
    property OfonoNetworkRegistration netreg: OfonoNetworkRegistration {
        modemPath: network.modemPath
    }
    property OfonoRadioSettings radio: OfonoRadioSettings {
        modemPath: network.modemPath
    }
    property OfonoSimManager sim: OfonoSimManager {
        modemPath: network.modemPath
    }
    property OfonoConnMan connMan: OfonoConnMan {
        modemPath: network.modemPath
    }
    property CellMonitor cellMonitor: CellMonitor {
        modemPath: network.modemPath
    }
}
