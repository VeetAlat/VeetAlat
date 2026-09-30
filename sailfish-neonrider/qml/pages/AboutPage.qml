import QtQuick 2.0
import Sailfish.Silica 1.0
import "../js/about.js" as About

// How to play, disclaimers, and who made the game.
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
                title: "About Neon Rider"
                description: "How to play and disclaimers"
            }

            SectionHeader { text: "How to play" }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.highlightColor
                text: "Your bike races down a neon tunnel, faster and faster. The "
                      + "floor, the walls and the roof are all road.\n"
                      + "• The arrow buttons move one lane left or right. Keep going past the "
                      + "edge of the floor and you ride up the wall; the view turns "
                      + "with you.\n"
                      + "• The round button jumps. Jump over gaps and over the blocks.\n"
                      + "• Black holes with an orange edge are where the road is "
                      + "gone. Ride round them on another side, or jump.\n"
                      + "• The game pauses when you leave it."
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
                      + "It runs only on your device and never uses the internet: it "
                      + "has no network permission at all. No account, no tracking, "
                      + "no analytics. Only your best distance and bike colour are "
                      + "saved, on your phone."
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
