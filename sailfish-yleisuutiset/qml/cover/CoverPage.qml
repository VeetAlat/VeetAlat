import QtQuick 2.0
import Sailfish.Silica 1.0
import "../pages"

// The latest headlines of the current category, one at a time.
CoverBackground {
    id: cover

    property NewsStore news
    property int shown: 0

    readonly property var items: news ? news.items : []
    readonly property var article: items.length > 0 ? items[shown % Math.min(items.length, 5)] : null

    Timer {
        interval: 6000
        repeat: true
        running: cover.status === Cover.Active && cover.items.length > 1
        onTriggered: cover.shown++
    }

    Column {
        x: Theme.paddingLarge
        y: Theme.paddingLarge
        width: parent.width - 2 * x
        spacing: Theme.paddingSmall

        Label {
            width: parent.width
            truncationMode: TruncationMode.Fade
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.highlightColor
            text: cover.news ? "Yleisuutiset · " + cover.news.category.name : "Yleisuutiset"
        }
        Label {
            width: parent.width
            wrapMode: Text.Wrap
            maximumLineCount: 6
            elide: Text.ElideRight
            font.pixelSize: Theme.fontSizeSmall
            textFormat: Text.PlainText
            text: cover.article ? cover.article.title : (cover.news && cover.news.loading ? "Loading…" : "No news")
        }
    }

    CoverActionList {
        CoverAction {
            iconSource: "image://theme/icon-cover-refresh"
            onTriggered: cover.news.refresh()
        }
        CoverAction {
            iconSource: "image://theme/icon-cover-next"
            onTriggered: cover.shown++
        }
    }
}
