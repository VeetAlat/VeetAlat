import QtQuick 2.0
import Sailfish.Silica 1.0

// A category as a tappable button; the current one is filled and outlined.
MouseArea {
    id: button

    property string text
    property string subtitle
    property bool selected

    implicitWidth: Math.max(Theme.itemSizeLarge, label.implicitWidth + 2 * Theme.paddingLarge)
    implicitHeight: subtitle ? Theme.itemSizeMedium : Theme.itemSizeExtraSmall

    Rectangle {
        anchors.fill: parent
        radius: Theme.paddingSmall
        color: button.selected || button.pressed
               ? Theme.rgba(Theme.highlightBackgroundColor, Theme.highlightBackgroundOpacity)
               : Theme.rgba(Theme.primaryColor, 0.08)
        border.width: button.selected ? 2 : 0
        border.color: Theme.highlightColor
    }
    Column {
        anchors.centerIn: parent
        width: parent.width - 2 * Theme.paddingMedium
        Label {
            id: label
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            truncationMode: TruncationMode.Fade
            font.bold: button.selected
            color: button.selected || button.pressed ? Theme.highlightColor : Theme.primaryColor
            text: button.text
        }
        Label {
            width: parent.width
            visible: button.subtitle !== ""
            horizontalAlignment: Text.AlignHCenter
            truncationMode: TruncationMode.Fade
            font.pixelSize: Theme.fontSizeExtraSmall
            color: Theme.secondaryColor
            text: button.subtitle
        }
    }
}
