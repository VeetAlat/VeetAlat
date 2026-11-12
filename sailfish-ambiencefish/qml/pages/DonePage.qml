import QtQuick 2.0
import Sailfish.Silica 1.0
import AmbienceFish 1.0

// The finished square: make it an ambience (and switch to it, if wanted),
// or open it in the Gallery.
Page {
    id: page

    property Composer composer
    property string path
    property string message: ""     // what happened with the ambience
    property bool working: false
    property bool created: false

    // Tests set this to see where a tap would go.
    property var openLink: function(link) { Qt.openUrlExternally(link) }

    allowedOrientations: Orientation.All

    function makeAmbience(useNow) {
        working = true
        message = useNow ? "Making the ambience and switching to it…" : "Making the ambience…"
        composer.createAmbience(path, useNow)
    }

    Connections {
        target: page.composer
        onAmbienceDone: {
            page.working = false
            if (error !== "") {
                page.message = "The ambience couldn't be made: " + error
                    + ". You can still make it from the Gallery: open the picture there and tap the ambience button."
                return
            }
            page.created = true
            page.message = "Done! Find it in Settings → Ambience, where you can name it and pick its colours and sounds."
        }
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge * 2

        VerticalScrollDecorator { }

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingLarge

            PageHeader {
                title: "Saved"
                description: page.path.replace(/^.*\//, "")
            }

            Image {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                height: width
                source: page.path !== "" ? "file://" + page.path : ""
                sourceSize.width: 1024
                sourceSize.height: 1024
                fillMode: Image.PreserveAspectFit
                asynchronous: true
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryHighlightColor
                text: "Saved in Pictures/AmbienceFish, 2048 × 2048 like Sailfish's own ambiences. " +
                      "If Settings asks you to crop it, keep the whole square."
            }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                preferredWidth: Theme.buttonWidthLarge
                text: "Make an ambience"
                enabled: !page.working
                onClicked: page.makeAmbience(false)
            }
            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                preferredWidth: Theme.buttonWidthLarge
                text: "Make it and use it now"
                enabled: !page.working
                onClicked: page.makeAmbience(true)
            }

            BusyIndicator {
                anchors.horizontalCenter: parent.horizontalCenter
                running: page.working
                visible: running
                size: BusyIndicatorSize.Medium
            }

            Label {
                visible: page.message !== ""
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                color: page.message.indexOf("couldn't") >= 0 ? Theme.errorColor : Theme.highlightColor
                text: page.message
            }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                preferredWidth: Theme.buttonWidthLarge
                text: "Open in Gallery"
                onClicked: page.openLink("file://" + page.path)
            }
            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                preferredWidth: Theme.buttonWidthLarge
                text: "Make another"
                onClicked: pageStack.pop(pageStack.find(function(p) { return p.hasOwnProperty("pendingSource") }))
            }
        }
    }
}
