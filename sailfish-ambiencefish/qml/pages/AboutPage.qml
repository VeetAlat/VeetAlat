import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: page

    readonly property string author: "Valatalo"
    readonly property string version: "0.1.0"

    // Tests set this to see where a tap would go instead of opening the browser.
    property var openLink: function(link) { Qt.openUrlExternally(link) }

    allowedOrientations: Orientation.All

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge * 2

        VerticalScrollDecorator { }

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingMedium

            PageHeader {
                title: "About AmbienceFish"
                description: "Version " + page.version
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                color: Theme.highlightColor
                text: "Sailfish ambiences use a square picture, 2048 × 2048, and show only its middle: " +
                      "a tall strip when the phone is upright and a wide one when it's turned. " +
                      "AmbienceFish lets you place a photo on that square yourself, shows exactly what each " +
                      "screen will see, and fills the rest with a blur of the photo, so the ambience " +
                      "shows what you chose."
            }

            SectionHeader { text: "Disclaimers" }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryHighlightColor
                text: "This app has been created using AI generated code (Claude code)."
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryHighlightColor
                text: "Your photos stay on your phone. AmbienceFish reads the photo you choose, saves the " +
                      "new picture in Pictures/AmbienceFish, and asks the phone's ambience service to make " +
                      "the ambience. It has no network use, account or tracking."
            }

            SectionHeader { text: "Made by" }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                color: Theme.highlightColor
                text: page.author
            }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                preferredWidth: Theme.buttonWidthLarge
                text: "More from me"
                onClicked: page.openLink("https://openrepos.net/user/19764/programs")
            }
        }
    }
}
