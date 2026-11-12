import QtQuick 2.0
import Sailfish.Silica 1.0

// The last picture made, or the app's name.
CoverBackground {
    id: cover

    property string image: ""

    Image {
        anchors.fill: parent
        visible: cover.image !== ""
        source: cover.image !== "" ? "file://" + cover.image : ""
        sourceSize.width: 512
        sourceSize.height: 512
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        opacity: 0.6
    }

    Label {
        anchors.centerIn: parent
        width: parent.width - 2 * Theme.paddingLarge
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        font.pixelSize: Theme.fontSizeLarge
        color: Theme.highlightColor
        text: "AmbienceCrop"
    }
}
