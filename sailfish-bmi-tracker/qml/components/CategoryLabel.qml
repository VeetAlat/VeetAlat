import QtQuick 2.0
import Sailfish.Silica 1.0

// A category name with its colour swatch. The name is in text colour; the
// swatch carries the colour, so the meaning never depends on colour alone.
Row {
    property var category // from bmi.js, or null
    property alias font: name.font

    spacing: Theme.paddingSmall
    visible: !!category

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.paddingMedium * 1.5
        height: width
        radius: width / 2
        color: category ? category.color : "transparent"
    }
    Label {
        id: name
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.highlightColor
        text: category ? category.name : ""
    }
}
