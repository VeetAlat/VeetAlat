import QtQuick 2.0
import Sailfish.Silica 1.0
import "../js/about.js" as About

// About and disclaimers: how Yle's RSS terms are followed, AI assistance,
// privacy, and who made the app.
Page {
    id: page

    property NewsStore news
    property bool cleared: false

    // Tests set this to see where a tap would go instead of opening the browser.
    property var openLink: function(link) { Qt.openUrlExternally(link) }

    readonly property string openReposUrl: About.OPENREPOS_URL
    readonly property string author: About.AUTHOR

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
                title: "About UutisRSS"
                description: "Disclaimers"
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                color: Theme.highlightColor
                text: "UutisRSS shows the latest headlines from Yle, Finland's public "
                      + "broadcaster. It is an unofficial app, not made by or affiliated with Yle."
            }

            SectionHeader { text: "Made using Yle RSS, respecting the rules" }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryHighlightColor
                text: "The headlines come from Yle's public RSS feeds and are used "
                      + "following Yle's RSS terms of use:\n"
                      + "• Only headlines are shown, no photos and no article text.\n"
                      + "• Every headline opens the story on Yle's own site, yle.fi.\n"
                      + "• The app is free, with no ads or paid features.\n"
                      + "• Yle may change or end its feeds at any time."
            }
            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                preferredWidth: Theme.buttonWidthLarge
                text: "Read Yle's RSS terms"
                onClicked: page.openLink(About.YLE_RSS_TERMS_URL)
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
                text: "The app is non-profit. It runs only on your device: no account, "
                      + "no tracking, no analytics and no servers of its own. The only "
                      + "connection it makes is to fetch Yle's RSS feeds."
            }

            SectionHeader { text: "Fetched headlines" }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryHighlightColor
                text: "The headlines the app fetches from Yle (only the headline, its "
                      + "time, category and link) are kept on your phone so the app opens "
                      + "instantly and works offline. Nothing else is stored, and they never "
                      + "leave your phone. Yle's RSS terms say fetched content must be "
                      + "deleted if Yle asks; this button deletes all of it at once. The app "
                      + "fetches fresh headlines the next time it opens a category."
            }
            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                preferredWidth: Theme.buttonWidthLarge
                enabled: !page.cleared
                text: page.cleared ? "Fetched headlines deleted" : "Delete fetched headlines"
                onClicked: {
                    page.news.clearSaved()
                    page.cleared = true
                }
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
