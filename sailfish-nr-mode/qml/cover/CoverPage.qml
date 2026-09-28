import QtQuick 2.0
import Sailfish.Silica 1.0
import "../pages"

CoverBackground {
    Network { id: network }

    Column {
        anchors.centerIn: parent
        width: parent.width - 2 * Theme.paddingLarge
        spacing: Theme.paddingSmall

        Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: Theme.fontSizeExtraLarge
            text: network.technologyName(network.technology)
        }
        Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            color: Theme.secondaryColor
            text: network.strength + " %"
        }
        Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            color: Theme.highlightColor
            text: nrControl.busy ? "Switching…" : (nrControl.enabled ? "NR only" : "Normal")
        }
    }
}
