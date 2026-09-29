import QtQuick 2.0
import Sailfish.Silica 1.0
import Nemo.Configuration 1.0
import QOfono 0.2

Page {
    id: page

    property Network network
    property EventLog events

    allowedOrientations: Orientation.All

    // Seconds without registration before going back to normal mode,
    // 0 for never. A first SA scan after the radio restarts can take a
    // few minutes, hence the 3 minute default.
    ConfigurationValue {
        id: revertAfter
        key: "/apps/nr-mode/revertAfter"
        defaultValue: 180
    }
    readonly property var revertChoices: [60, 180, 300, 0]

    RemorsePopup { id: remorse }

    function describe(state) {
        if (state === "on") return "NR only is active."
        if (state === "off" || state === "") return "Normal network selection."
        var i = state.indexOf(":")
        var text = i < 0 ? state : state.substring(i + 1).trim()
        return text.charAt(0).toUpperCase() + text.substring(1)
    }

    function yesNo(value) { return value ? "Yes" : "No" }

    function pinName(pin) {
        switch (pin) {
        case OfonoSimManager.NoPin: return "None"
        case OfonoSimManager.SimPin: return "PIN required"
        case OfonoSimManager.SimPuk: return "PUK required (SIM blocked)"
        default: return "Locked (" + pin + ")"
        }
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        PullDownMenu {
            MenuItem {
                text: "Diagnostics report"
                onClicked: pageStack.push(Qt.resolvedUrl("DiagnosticsPage.qml"))
            }
            MenuItem {
                text: "Monitor and log"
                onClicked: pageStack.push(Qt.resolvedUrl("MonitorPage.qml"), { events: page.events })
            }
        }

        VerticalScrollDecorator { }

        Column {
            id: column
            width: parent.width

            PageHeader { title: "NR Mode" }

            SectionHeader { text: "Mode" }

            TextSwitch {
                text: "5G NR only (SA)"
                description: "Use only 5G standalone cells and ignore LTE, 3G and 2G."
                automaticCheck: false
                checked: nrControl.enabled
                busy: nrControl.busy
                enabled: !nrControl.busy
                onClicked: {
                    if (checked) {
                        nrControl.request("off")
                    } else {
                        var mode = revertAfter.value > 0 ? "on-" + revertAfter.value : "on-keep"
                        remorse.execute("Restarting cellular for NR only",
                                        function() { nrControl.request(mode) })
                    }
                }
            }

            ComboBox {
                label: "Revert without 5G SA"
                description: "Go back to normal mode if the phone hasn't registered to a network by then."
                enabled: !nrControl.busy
                // Set once rather than bound: binding currentIndex to the
                // value this ComboBox itself writes is a binding loop.
                property bool ready
                Component.onCompleted: {
                    currentIndex = Math.max(0, page.revertChoices.indexOf(revertAfter.value))
                    ready = true
                }
                menu: ContextMenu {
                    MenuItem { text: "After 1 minute" }
                    MenuItem { text: "After 3 minutes" }
                    MenuItem { text: "After 5 minutes" }
                    MenuItem { text: "Never" }
                }
                onCurrentIndexChanged: if (ready) revertAfter.value = page.revertChoices[currentIndex]
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                color: Theme.highlightColor
                text: page.describe(nrControl.state)
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: !network.nrCapable && network.availableTechnologies.length > 0
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryHighlightColor
                text: "ofono doesn't list 5G for this modem. That list comes from the "
                      + "phone's ofono config, not the modem itself, so NR only can "
                      + "still work. Keep an automatic revert on the first time."
            }

            SectionHeader { text: "Network" }

            DetailItem { label: "Operator"; value: network.operatorName || "–" }
            DetailItem { label: "Registration"; value: network.status || "–" }
            DetailItem { label: "Technology"; value: network.technologyName(network.technology) }
            DetailItem { label: "Signal"; value: network.strength + " %" }
            DetailItem {
                label: "Network code"
                value: network.mcc ? network.mcc + " " + network.mnc : "–"
            }
            DetailItem { label: "Preferred mode"; value: network.preference || "–" }
            DetailItem {
                label: "Modem supports"
                value: network.availableTechnologies.join(", ") || "–"
            }

            SectionHeader { text: "Cells" }

            DetailItem {
                label: "Serving cell"
                value: network.servingCell ? network.cellTypeName(network.servingCell.type) : "None"
            }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: !!network.servingCell
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignRight
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.highlightColor
                text: network.cellSignal(network.servingCell)
            }
            DetailItem {
                label: "Cells visible"
                value: network.cells.length + " (" + network.nrCellCount + " 5G NR)"
            }
            DetailItem {
                label: "Bands seen"
                value: network.bandSummary || "–"
            }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: network.n77OnlySeen
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryHighlightColor
                text: "A cell above 3.8 GHz (n77 only) is visible, so this modem can at "
                      + "least receive n77 frequencies there."
            }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: network.cells.length > 0 && network.nrCellCount === 0
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryHighlightColor
                text: "The modem sees no 5G NR cell here, so NR only mode can't connect."
            }

            SectionHeader { text: "SIM" }

            DetailItem { label: "Present"; value: page.yesNo(network.simPresent) }
            DetailItem { label: "Provider"; value: network.simProvider || "–" }
            DetailItem {
                label: "Home network"
                value: network.simMcc ? network.simMcc + " " + network.simMnc : "–"
            }
            DetailItem { label: "PIN"; value: page.pinName(network.simPinRequired) }

            SectionHeader { text: "Mobile data" }

            DetailItem { label: "Data enabled"; value: page.yesNo(network.dataEnabled) }
            DetailItem { label: "Attached"; value: page.yesNo(network.attached) }
            DetailItem { label: "Bearer"; value: network.bearer || "none" }
            DetailItem { label: "Roaming allowed"; value: page.yesNo(network.roamingAllowed) }

            Repeater {
                model: network.contexts
                delegate: ContextItem { contextPath: modelData }
            }

            SectionHeader { text: "Before you switch" }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryHighlightColor
                text: "Switching restarts the cellular service, which drops "
                      + "ongoing calls and mobile data for a few seconds.\n\n"
                      + "In NR only mode the phone has no service at all "
                      + "outside 5G standalone coverage. Calls and SMS only "
                      + "work if your operator supports VoNR, and emergency "
                      + "calls may not work either. The mode survives reboots "
                      + "until you switch it off here."
            }
        }
    }
}
