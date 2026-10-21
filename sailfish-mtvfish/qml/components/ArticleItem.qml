import QtQuick 2.0
import Sailfish.Silica 1.0
import "../js/rss.js" as Rss

// One headline. Tapping it opens the whole story in the app; press and
// hold to open it on mtvuutiset.fi or copy its link.
ListItem {
    id: item

    property var article
    property bool leading: false  // the first headline is shown larger (not "top": Item has that)
    property bool hot: false      // one of the newest top headlines: bold, with "Hot 🔥"
    property real now: Date.now()

    signal readRequested()
    signal openRequested(string link)

    contentHeight: column.height + 2 * Theme.paddingMedium
    onClicked: item.readRequested()

    menu: ContextMenu {
        MenuItem {
            text: "Read in MTVFish"
            onClicked: item.readRequested()
        }
        MenuItem {
            text: "Open on mtvuutiset.fi"
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
            font.bold: item.hot
            color: item.highlighted ? Theme.highlightColor : Theme.primaryColor
            textFormat: Text.PlainText
            text: item.article.title
        }
        Row {
            width: parent.width
            spacing: Theme.paddingSmall

            Label {
                id: meta
                width: Math.min(implicitWidth, parent.width - (hotLabel.visible ? hotLabel.width + parent.spacing : 0))
                truncationMode: TruncationMode.Fade
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryHighlightColor
                text: [Rss.relativeTime(item.article.date, item.now),
                       item.article.categories.length > 0 ? item.article.categories[0] : "",
                       "MTV"]
                      .filter(function(s) { return s }).join(" · ")
            }
            Label {
                id: hotLabel
                visible: item.hot
                font.pixelSize: Theme.fontSizeExtraSmall
                font.bold: true
                color: Theme.highlightColor
                text: "· Hot \ud83d\udd25"
            }
        }
    }
}
