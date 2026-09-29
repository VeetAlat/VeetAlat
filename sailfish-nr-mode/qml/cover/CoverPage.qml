import QtQuick 2.0
import Sailfish.Silica 1.0
import "../pages"

CoverBackground {
    property Network network

    Column {
        anchors.centerIn: parent
        width: parent.width - 2 * Theme.paddingLarge
        spacing: Theme.paddingSmall

        Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: Theme.fontSizeExtraLarge
            fontSizeMode: Text.HorizontalFit
            text: network.technologyName(network.technology)
        }
        Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            color: Theme.secondaryColor
            font.pixelSize: Theme.fontSizeSmall
            wrapMode: Text.Wrap
            text: network.servingCell
                  ? network.cellSignal(network.servingCell).split(" · ")[0]
                  : network.strength + " %"
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
