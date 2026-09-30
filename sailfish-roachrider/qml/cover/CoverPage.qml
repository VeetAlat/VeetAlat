import QtQuick 2.0
import Sailfish.Silica 1.0

// The app's cover: the name and the best distance, over the faint icon.
CoverBackground {
    Image {
        anchors.centerIn: parent
        width: parent.width * 0.9
        height: width
        source: "/usr/share/icons/hicolor/172x172/apps/roachrider.png"
        sourceSize { width: width; height: height }
        opacity: 0.25
    }

    Column {
        anchors.centerIn: parent
        width: parent.width - 2 * Theme.paddingLarge
        spacing: Theme.paddingMedium

        Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: Theme.fontSizeLarge
            font.bold: true
            color: "#ff2bd6"
            text: "Roach Rider"
        }
        Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            color: Theme.secondaryColor
            font.pixelSize: Theme.fontSizeSmall
            text: gameEngine.paused ? "Paused" : "Best"
        }
        Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: Theme.fontSizeExtraLarge
            color: "#19c6ff"
            text: (gameEngine.paused ? gameEngine.score : gameEngine.best) + " m"
        }
    }
}
