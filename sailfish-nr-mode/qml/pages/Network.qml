import QtQuick 2.0
import QOfono 0.2

// Live view of the default modem, shared by the page and the cover.
QtObject {
    readonly property string operatorName: netreg.name
    readonly property string technology: netreg.technology
    readonly property int strength: netreg.strength
    readonly property string status: netreg.status
    readonly property string preference: radio.technologyPreference
    readonly property bool nrCapable: radio.availableTechnologies.indexOf("nr") >= 0

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

    property OfonoManager manager: OfonoManager { }
    property OfonoNetworkRegistration netreg: OfonoNetworkRegistration {
        modemPath: manager.defaultModem
    }
    property OfonoRadioSettings radio: OfonoRadioSettings {
        modemPath: manager.defaultModem
    }
}
