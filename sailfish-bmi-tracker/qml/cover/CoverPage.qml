import QtQuick 2.0
import Sailfish.Silica 1.0
import "../pages"
import "../js/bmi.js" as Bmi

CoverBackground {
    id: cover

    property Store store
    signal addRequested()

    Column {
        anchors.centerIn: parent
        width: parent.width - 2 * Theme.paddingLarge
        spacing: Theme.paddingSmall

        Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            color: Theme.secondaryColor
            font.pixelSize: Theme.fontSizeSmall
            text: "BMI"
        }
        Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: Theme.fontSizeHuge
            text: isNaN(cover.store.currentBmi) ? "–" : Bmi.rounded(cover.store.currentBmi).toFixed(1)
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.paddingSmall
            visible: !!cover.store.currentCategory
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.paddingMedium
                height: width
                radius: width / 2
                color: cover.store.currentCategory ? cover.store.currentCategory.color : "transparent"
            }
            Label {
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.highlightColor
                text: cover.store.currentCategory ? cover.store.currentCategory.name : ""
            }
        }
    }

    CoverActionList {
        enabled: cover.store.hasProfile
        CoverAction {
            iconSource: "image://theme/icon-cover-new"
            onTriggered: cover.addRequested()
        }
    }
}
