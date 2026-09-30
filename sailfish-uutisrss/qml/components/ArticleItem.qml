import QtQuick 2.0
import Sailfish.Silica 1.0
import "../js/rss.js" as Rss

// One headline. Following Yle's RSS terms it shows only the headline (no
// photo, no summary) and tapping it opens the story on Yle's own site.
// Press and hold for "Copy link".
ListItem {
    id: item

    property var article
    property bool leading: false  // the first headline is shown larger (not "top": Item has that)
    property real now: Date.now()

    signal openRequested(string link)

    contentHeight: column.height + 2 * Theme.paddingMedium
    onClicked: item.openRequested(item.article.link)

    menu: ContextMenu {
        MenuItem {
            text: "Read on yle.fi"
            onClicked: item.openRequested(item.article.link)
        }
        MenuItem {
            text: "Copy link"
            onClicked: Clipboard.text = item.article.link
        }
    }

    Column {
        id: column
        y: Theme.paddingMedium
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        spacing: Theme.paddingSmall / 2

        Label {
            width: parent.width
            wrapMode: Text.Wrap
            maximumLineCount: 4
            elide: Text.ElideRight
            font.pixelSize: item.leading ? Theme.fontSizeLarge : Theme.fontSizeMedium
            color: item.highlighted ? Theme.highlightColor : Theme.primaryColor
            textFormat: Text.PlainText
            text: item.article.title
        }
        Label {
            width: parent.width
            truncationMode: TruncationMode.Fade
            font.pixelSize: Theme.fontSizeExtraSmall
            color: Theme.secondaryHighlightColor
            text: [Rss.relativeTime(item.article.date, item.now),
                   item.article.categories.length > 0 ? item.article.categories[0] : "",
                   "Yle"]
                  .filter(function(s) { return s }).join(" · ")
        }
    }
}
