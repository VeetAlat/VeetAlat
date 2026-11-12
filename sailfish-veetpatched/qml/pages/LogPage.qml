import QtQuick 2.0
import Sailfish.Silica 1.0
import VeetPatched 1.0

// What the helper did, newest last.
Page {
    property Patcher patcher

    allowedOrientations: Orientation.All

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        PullDownMenu {
            MenuItem {
                text: "Copy"
                onClicked: Clipboard.text = patcher.log
            }
        }

        VerticalScrollDecorator { }

        Column {
            id: column
            width: parent.width

            PageHeader { title: "Log" }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.WrapAnywhere
                font.family: "DejaVu Sans Mono"
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryHighlightColor
                text: patcher.log !== "" ? patcher.log : "Nothing yet."
            }
        }
    }
}
