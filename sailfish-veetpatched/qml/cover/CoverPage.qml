import QtQuick 2.0
import Sailfish.Silica 1.0
import VeetPatched 1.0

CoverBackground {
    property Patcher patcher

    readonly property int applied: {
        var n = 0
        if (patcher) for (var i = 0; i < patcher.patches.length; i++) if (patcher.patches[i].state === "applied") n++
        return n
    }

    Column {
        anchors.centerIn: parent
        width: parent.width - 2 * Theme.paddingLarge
        spacing: Theme.paddingSmall

        Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            color: Theme.highlightColor
            text: "VeetPatched"
        }
        Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: Theme.fontSizeSmall
            text: applied === 1 ? "1 patch on" : applied + " patches on"
        }
    }
}
