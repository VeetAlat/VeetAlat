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
                title: "About YleFish"
                description: "For personal use"
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                color: Theme.highlightColor
                text: "YleFish brings you Yle's news, Finland's public broadcaster, on "
                      + "your Sailfish phone: the headlines from Yle's RSS feeds, and each "
                      + "whole story, text and photos, right in the app. It is an unofficial "
                      + "app, not made by or affiliated with Yle."
            }

            SectionHeader { text: "For personal use only" }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryHighlightColor
                text: "YleFish is a private app. It reads each story from its page on yle.fi "
                      + "and shows its text and photos inside the app. Yle's RSS terms only "
                      + "allow apps to show headlines that link to yle.fi, so YleFish is not "
                      + "for sharing or publishing. The stories and photos belong to Yle."
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
                text: "This app has been created using AI generated code (Claude code)."
            }

            SectionHeader { text: "Non-profit, on your device only, private" }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryHighlightColor
                text: "The app is non-profit. It runs only on your device: no account, "
                      + "no tracking, no analytics and no servers of its own. It only "
                      + "connects to Yle, to fetch the feeds, the stories and their photos."
            }

            SectionHeader { text: "Saved news" }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryHighlightColor
                text: "The headlines, their summaries and photo addresses are kept on "
                      + "your phone so the app opens instantly and works offline. Whole "
                      + "stories are only kept in memory while the app runs. Nothing leaves "
                      + "your phone. This button deletes everything saved at once; the app "
                      + "fetches fresh news the next time it opens a category."
            }
            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                preferredWidth: Theme.buttonWidthLarge
                enabled: !page.cleared
                text: page.cleared ? "Saved news deleted" : "Delete saved news"
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
