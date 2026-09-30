import QtQuick 2.0
import Sailfish.Silica 1.0
import "../js/rss.js" as Rss

// An article's picture, headline and lede from the feed, with a button to
// read the whole story on yle.fi.
Page {
    id: page

    property var article

    allowedOrientations: Orientation.All

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        PullDownMenu {
            MenuItem {
                text: "Copy link"
                onClicked: {
                    Clipboard.text = page.article.link
                    copied.visible = true
                }
            }
            MenuItem {
                text: "Open in the browser"
                onClicked: Qt.openUrlExternally(page.article.link)
            }
        }

        VerticalScrollDecorator { }

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingMedium

            PageHeader { title: page.article.categories.length > 0 ? page.article.categories[0] : "Yle" }

            Image {
                visible: page.article.image !== "" && status !== Image.Error
                width: parent.width
                height: visible ? width * 9 / 16 : 0
                fillMode: Image.PreserveAspectCrop
                clip: true
                asynchronous: true
                sourceSize.width: width
                source: page.article.image
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeLarge
                color: Theme.highlightColor
                textFormat: Text.PlainText
                text: page.article.title
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryHighlightColor
                text: [isFinite(page.article.date)
                       ? Qt.formatDateTime(new Date(page.article.date), Qt.DefaultLocaleShortDate) : "",
                       page.article.categories.join(", ")].filter(function(s) { return s }).join(" · ")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: page.article.summary !== ""
                wrapMode: Text.Wrap
                textFormat: Text.PlainText
                text: page.article.summary
            }

            Item { width: 1; height: Theme.paddingMedium }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                preferredWidth: Theme.buttonWidthLarge
                text: "Read the full article"
                onClicked: Qt.openUrlExternally(page.article.link)
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                text: "Opens the story on yle.fi in your browser."
            }
            Label {
                id: copied
                visible: false
                anchors.horizontalCenter: parent.horizontalCenter
                color: Theme.highlightColor
                text: "Link copied"
            }
        }
    }
}
