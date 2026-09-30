import QtQuick 2.0
import Sailfish.Silica 1.0
import "../js/about.js" as About

// What the game is, disclaimers, and who made it.
Page {
    id: page

    // Tests set this to see where a tap would go instead of opening the browser.
    property var openLink: function(link) { Qt.openUrlExternally(link) }

    readonly property string openReposUrl: About.OPENREPOS_URL
    readonly property string author: About.AUTHOR

    allowedOrientations: Orientation.Portrait

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge * 2

        VerticalScrollDecorator { }

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingMedium

            PageHeader {
                title: "About Roach Rider"
                description: "Disclaimers"
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                color: Theme.highlightColor
                text: "The roach needs to ride its way through the neon grid! Use the arrows to move lanes, including to the walls and ceiling! Circle is used to jump. Don't hit the blocks, and don't fall into the ominous void!"
            }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryHighlightColor
                text: "The void is black with an orange edge. The ride gets faster "
                      + "the further you go, and pauses when you leave the game."
            }

            SectionHeader { text: "Made with AI-assisted tools" }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryHighlightColor
                text: "This game was made with the help of AI-assisted tools (Claude Code)."
            }

            SectionHeader { text: "Non-profit, on your device only, private" }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryHighlightColor
                text: "The game is non-profit: free, with no ads and nothing to buy. "
                      + "It runs only on your device and never uses the internet: its "
                      + "only permission is to play sound. No account, no tracking, "
                      + "no analytics. Only your best distance is saved, on your phone."
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
