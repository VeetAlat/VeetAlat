import QtQuick 2.0
import Sailfish.Silica 1.0
import Nemo.Configuration 1.0

Page {
    id: page

    allowedOrientations: Orientation.All

    Network { id: network }

    ConfigurationValue {
        id: autoRevert
        key: "/apps/nr-mode/autoRevert"
        defaultValue: true
    }

    RemorsePopup { id: remorse }

    function describe(state) {
        if (state === "on") return "NR only is active."
        if (state === "off" || state === "") return "Normal network selection."
        var i = state.indexOf(":")
        var text = i < 0 ? state : state.substring(i + 1).trim()
        return text.charAt(0).toUpperCase() + text.substring(1)
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        VerticalScrollDecorator { }

        Column {
            id: column
            width: parent.width

            PageHeader { title: "NR Mode" }

            SectionHeader { text: "Network" }

            DetailItem { label: "Operator"; value: network.operatorName || "–" }
            DetailItem { label: "Technology"; value: network.technologyName(network.technology) }
            DetailItem { label: "Signal"; value: network.strength + " %" }
            DetailItem { label: "Registration"; value: network.status || "–" }

            SectionHeader { text: "Mode" }

            TextSwitch {
                text: "5G NR only (SA)"
                description: "Use only 5G standalone cells and ignore LTE, 3G and 2G."
                automaticCheck: false
                checked: nrControl.enabled
                busy: nrControl.busy
                enabled: !nrControl.busy && (network.nrCapable || nrControl.enabled)
                onClicked: {
                    if (checked) {
                        nrControl.request("off")
                    } else {
                        var mode = autoRevert.value ? "on" : "on-keep"
                        remorse.execute("Restarting cellular for NR only",
                                        function() { nrControl.request(mode) })
                    }
                }
            }

            TextSwitch {
                text: "Revert without 5G SA"
                description: "Go back to normal mode if no 5G standalone cell is found within 60 seconds."
                checked: autoRevert.value
                enabled: !nrControl.busy
                onCheckedChanged: autoRevert.value = checked
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
                visible: !network.nrCapable && !nrControl.enabled
                wrapMode: Text.Wrap
                color: Theme.errorColor
                text: "This modem does not report 5G NR support."
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
