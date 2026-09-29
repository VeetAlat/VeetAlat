import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: page

    property EventLog events

    allowedOrientations: Orientation.All

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        PullDownMenu {
            MenuItem {
                text: "Copy events and log"
                onClicked: {
                    Clipboard.text = "== Events\n" + page.events.asText()
                                   + "\n\n== Helper log\n" + nrControl.log
                    copied.visible = true
                }
            }
            MenuItem {
                text: "Clear events"
                onClicked: page.events.model.clear()
            }
        }

        VerticalScrollDecorator { }

        Column {
            id: column
            width: parent.width

            PageHeader { title: "Monitor" }

            Label {
                id: copied
                visible: false
                x: Theme.horizontalPageMargin
                color: Theme.highlightColor
                text: "Copied to clipboard"
            }

            SectionHeader { text: "Live events (newest first)" }

            Repeater {
                model: page.events.model
                delegate: Label {
                    x: Theme.horizontalPageMargin
                    width: column.width - 2 * x
                    wrapMode: Text.Wrap
                    font.pixelSize: Theme.fontSizeExtraSmall
                    textFormat: Text.PlainText
                    text: model.time + "  " + model.text
                }
            }

            SectionHeader { text: "Helper log (what the root helper did)" }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.WrapAnywhere
                font.family: "Monospace"
                font.pixelSize: Theme.fontSizeTiny
                textFormat: Text.PlainText
                color: Theme.secondaryColor
                text: nrControl.log || "Nothing yet. The helper logs here when you switch modes."
            }
        }
    }
}
