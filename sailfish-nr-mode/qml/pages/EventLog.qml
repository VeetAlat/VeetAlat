import QtQuick 2.0

// Timeline of everything that changes on the modem while the app runs,
// newest first. Lives as long as the app, so nothing is missed while the
// Monitor page is closed.
QtObject {
    id: eventLog

    property Network network
    property QtObject control // nrControl

    readonly property ListModel model: ListModel { }

    function add(text) {
        model.insert(0, { time: Qt.formatTime(new Date(), "hh:mm:ss"), text: text })
        if (model.count > 300) {
            model.remove(300, model.count - 300)
        }
    }

    function asText() {
        var lines = []
        for (var i = model.count - 1; i >= 0; i--) {
            lines.push(model.get(i).time + " " + model.get(i).text)
        }
        return lines.join("\n")
    }

    property Connections networkEvents: Connections {
        target: eventLog.network
        onStatusChanged: eventLog.add("Registration: " + (network.status || "none"))
        onTechnologyChanged: eventLog.add("Technology: " + network.technologyName(network.technology))
        onOperatorNameChanged: eventLog.add("Operator: " + (network.operatorName || "none"))
        onPreferenceChanged: eventLog.add("Preferred mode: " + network.preference)
        onAttachedChanged: eventLog.add(network.attached ? "Data attached" : "Data detached")
        onBearerChanged: eventLog.add("Data bearer: " + (network.bearer || "none"))
        onSimPresentChanged: eventLog.add(network.simPresent ? "SIM present" : "SIM missing")
        onServingCellChanged: {
            var c = network.servingCell
            var key = c ? c.type + "/" + (c.props.pci !== undefined ? c.props.pci : "?") : ""
            if (key !== eventLog.lastServing) {
                eventLog.lastServing = key
                eventLog.add(c ? "Serving cell: " + network.cellTypeName(c.type) + " · "
                                 + network.cellSignal(c)
                               : "No serving cell")
            }
        }
        onNrCellCountChanged: eventLog.add("5G NR cells visible: " + network.nrCellCount)
    }
    property string lastServing: "-"

    property Connections controlEvents: Connections {
        target: eventLog.control
        onChanged: {
            if (control.state && control.state !== eventLog.lastState) {
                eventLog.lastState = control.state
                eventLog.add("Helper: " + control.state)
            }
        }
    }
    property string lastState: ""

    Component.onCompleted: add("NR Mode started")
}
