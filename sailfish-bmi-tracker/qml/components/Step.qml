import QtQuick 2.0
import Sailfish.Silica 1.0

// A numbered step: a big number next to a title and an explanation.
Item {
    id: step

    property int number
    property string title
    property string explanation

    width: parent ? parent.width : 0
    height: Math.max(numberLabel.height, textColumn.height) + Theme.paddingMedium

    Label {
        id: numberLabel
        x: Theme.horizontalPageMargin
        width: Theme.itemSizeExtraSmall
        font.pixelSize: Theme.fontSizeExtraLarge
        color: Theme.highlightColor
        text: step.number
    }
    Column {
        id: textColumn
        anchors.left: numberLabel.right
        anchors.right: parent.right
        anchors.rightMargin: Theme.horizontalPageMargin
        Label {
            width: parent.width
            wrapMode: Text.Wrap
            color: Theme.highlightColor
            text: step.title
        }
        Label {
            width: parent.width
            wrapMode: Text.Wrap
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.secondaryHighlightColor
            text: step.explanation
        }
    }
}
