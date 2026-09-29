import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: page

    property bool waiting

    allowedOrientations: Orientation.All

    function refresh() {
        waiting = nrControl.request("diag")
    }

    Component.onCompleted: refresh()

    Connections {
        target: nrControl
        onDiagnosticsChanged: page.waiting = false
    }

    // The helper usually answers within a couple of seconds; stop the
    // spinner rather than spin forever if it never does.
    Timer {
        running: page.waiting
        interval: 20000
        onTriggered: page.waiting = false
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        PullDownMenu {
            busy: page.waiting
            MenuItem {
                text: "Copy report"
                enabled: nrControl.diagnostics !== ""
                onClicked: {
                    Clipboard.text = nrControl.diagnostics
                    copied.visible = true
                }
            }
            MenuItem {
                text: "Refresh report"
                onClicked: page.refresh()
            }
        }

        VerticalScrollDecorator { }

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingSmall

            PageHeader {
                title: "Diagnostics"
                description: "Modem, SIM, APN, cells and ofono log"
            }

            Label {
                id: copied
                visible: false
                x: Theme.horizontalPageMargin
                color: Theme.highlightColor
                text: "Copied to clipboard"
            }

            BusyIndicator {
                anchors.horizontalCenter: parent.horizontalCenter
                size: BusyIndicatorSize.Medium
                running: page.waiting
                visible: running
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.WrapAnywhere
                font.family: "Monospace"
                font.pixelSize: Theme.fontSizeTiny
                textFormat: Text.PlainText
                text: nrControl.diagnostics
                      || (page.waiting ? "Collecting…" : "No report. Is the helper service installed?")
            }
        }
    }
}
