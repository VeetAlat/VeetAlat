import QtQuick 2.0
import Sailfish.Silica 1.0
import "../js/about.js" as About

// About and disclaimers: health note, AI assistance, privacy, and who made
// the app.
Page {
    id: page

    property Store store

    // Tests set this to see where a tap would go instead of opening the browser.
    property var openLink: function(link) { Qt.openUrlExternally(link) }

    readonly property string openReposUrl: About.OPENREPOS_URL
    readonly property string author: About.AUTHOR

    allowedOrientations: Orientation.All

    RemorsePopup { id: remorse }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge * 2

        VerticalScrollDecorator { }

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingMedium

            PageHeader {
                title: "About BMI Tracker"
                description: "Disclaimers"
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                color: Theme.highlightColor
                text: "BMI Tracker works out your body mass index from your height and "
                      + "weight and keeps a history of it."
            }

            SectionHeader { text: "Not medical advice" }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryHighlightColor
                text: "BMI is a rough screening number, not a diagnosis. It doesn't "
                      + "tell muscle from fat and suits some people poorly, for example "
                      + "athletes, pregnant people, older adults and anyone under 20. "
                      + "The categories follow the WHO adult ranges. For advice about "
                      + "your weight or health, talk to a doctor or nurse."
            }

            SectionHeader { text: "Made with AI-assisted tools" }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryHighlightColor
                text: "This app was made with the help of AI-assisted tools (Claude Code)."
            }

            SectionHeader { text: "Non-profit, on your device only, private" }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryHighlightColor
                text: "The app is non-profit. It runs only on your device and never "
                      + "uses the internet: it has no network permission at all. No "
                      + "account, no tracking, no analytics. Your height, age, gender "
                      + "and weights are saved only on your phone, and you can delete "
                      + "them here at any time."
            }
            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                preferredWidth: Theme.buttonWidthLarge
                text: "Delete all my data"
                onClicked: remorse.execute("Deleting profile and weights",
                                           function() { page.store.clearAll() })
            }

            Item { width: 1; height: Theme.paddingLarge }

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                font.pixelSize: Theme.fontSizeLarge
                color: Theme.highlightColor
                text: "Made by " + page.author
            }
            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                preferredWidth: Theme.buttonWidthLarge
                visible: page.openReposUrl !== ""
                text: "More apps on OpenRepos"
                onClicked: page.openLink(page.openReposUrl)
            }
        }
    }
}
