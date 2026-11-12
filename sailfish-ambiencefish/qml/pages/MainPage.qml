import QtQuick 2.0
import Sailfish.Silica 1.0
import Sailfish.Pickers 1.0
import AmbienceFish 1.0

// Start here: pick a photo, from the gallery or from the files.
Page {
    id: page

    property Composer composer
    property string pendingSource: ""   // the editor opens once the picker has gone

    allowedOrientations: Orientation.All

    function edit(source) {
        return pageStack.push(Qt.resolvedUrl("EditorPage.qml"), { composer: page.composer, source: source })
    }

    onStatusChanged: {
        if (status === PageStatus.Active && pendingSource !== "") {
            var s = pendingSource
            pendingSource = ""
            edit(s)
        }
    }

    Component {
        id: imagePicker
        ImagePickerPage {
            onSelectedContentChanged: page.pendingSource = selectedContent.toString()
        }
    }
    Component {
        id: filePicker
        FilePickerPage {
            nameFilters: ["*.jpg", "*.jpeg", "*.JPG", "*.JPEG", "*.png", "*.PNG"]
            onSelectedContentPropertiesChanged: page.pendingSource = selectedContentProperties.filePath
        }
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge * 2

        PullDownMenu {
            MenuItem {
                text: "About"
                onClicked: pageStack.push(Qt.resolvedUrl("AboutPage.qml"))
            }
        }

        VerticalScrollDecorator { }

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingLarge

            PageHeader {
                title: "AmbienceFish"
                description: "Ambience photos, framed your way"
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                color: Theme.highlightColor
                text: "Ambiences use a square picture, and the phone only shows the middle of it: " +
                      "a tall strip when you hold it upright, a wide one when you turn it. " +
                      "Choose a photo, put it where you want it, and AmbienceFish fills the rest of " +
                      "the square with a soft blur of the photo, so nothing gets cut that you want to keep."
            }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                preferredWidth: Theme.buttonWidthLarge
                text: "Choose a photo"
                onClicked: pageStack.push(imagePicker)
            }
            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                preferredWidth: Theme.buttonWidthLarge
                text: "Browse files"
                onClicked: pageStack.push(filePicker)
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryHighlightColor
                text: "JPEG and PNG photos work. What you make is saved in Pictures/AmbienceFish, " +
                      "and can become an ambience straight away. The square pictures also make good " +
                      "profile photos."
            }
        }
    }
}
