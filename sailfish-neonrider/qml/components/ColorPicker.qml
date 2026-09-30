import QtQuick 2.0
import Sailfish.Silica 1.0

// Four round buttons, one per bike colour. The chosen one has a ring.
Row {
    id: picker

    property int selected: 1
    signal picked(int index)

    // Same order and colours as the bike in TunnelView.
    readonly property var colors: ["#ff2d55", "#2f8bff", "#2dff8a", "#ffd92f"]
    readonly property var names: ["Red", "Blue", "Green", "Yellow"]

    spacing: Theme.paddingLarge

    Repeater {
        model: 4

        Item {
            width: Theme.itemSizeMedium
            height: width

            Rectangle {
                anchors.centerIn: parent
                width: parent.width
                height: width
                radius: width / 2
                color: "transparent"
                border.width: Math.round(Theme.paddingSmall / 1.5)
                border.color: "#ffffff"
                visible: picker.selected === index
            }
            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 0.7
                height: width
                radius: width / 2
                color: picker.colors[index]
            }
            MouseArea {
                anchors.fill: parent
                onClicked: picker.picked(index)
            }
        }
    }
}
