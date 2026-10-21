import QtQuick 2.0
import Sailfish.Silica 1.0
import "../js/rss.js" as Rss

// The app's home: one big tile per news source (Yle, MTV Uutiset, AP
// News), each with its newest saved headline. Tapping one opens its
// headlines on the category last read there.
Page {
    id: page

    property NewsStore news

    // Tests set this to see where a tap would go instead of opening the browser.
    property var openLink: function(link) { Qt.openUrlExternally(link) }

    allowedOrientations: Orientation.All

    // Bumped whenever saved headlines may have changed, so tiles re-read them.
    property int revision: 0
    property real now: Date.now()
    onStatusChanged: if (status === PageStatus.Active) { now = Date.now(); revision++ }
    Connections {
        target: page.news
        onItemsChanged: page.revision++
    }

    function open(key) {
        news.openSource(key)
        return pageStack.push(Qt.resolvedUrl("MainPage.qml"), { news: news, openLink: page.openLink })
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        PullDownMenu {
            MenuItem {
                text: "About"
                onClicked: pageStack.push(Qt.resolvedUrl("AboutPage.qml"), { news: page.news })
            }
        }

        VerticalScrollDecorator { }

        Column {
            id: column
            width: parent.width

            PageHeader {
                title: "UutisFish"
                description: "Yle · MTV Uutiset · AP News"
            }

            Repeater {
                model: page.news ? page.news.sources : []
                delegate: BackgroundItem {
                    id: tile
                    width: column.width
                    height: Math.max(badge.height, texts.height) + 2 * Theme.paddingLarge

                    readonly property var latest: {
                        page.revision
                        return page.news ? page.news.latestSaved(modelData.key) : null
                    }

                    onClicked: page.open(modelData.key)

                    // The source's colour along the left edge.
                    Rectangle {
                        width: Theme.paddingSmall
                        height: parent.height - 2 * Theme.paddingMedium
                        anchors.verticalCenter: parent.verticalCenter
                        color: modelData.color
                    }

                    // Its initials in a disc (no logos: an unofficial app).
                    Rectangle {
                        id: badge
                        x: Theme.horizontalPageMargin
                        y: Theme.paddingLarge
                        width: Theme.itemSizeMedium
                        height: width
                        radius: width / 2
                        color: modelData.color
                        Label {
                            anchors.centerIn: parent
                            font.pixelSize: modelData.key === "ap" ? Theme.fontSizeMedium : Theme.fontSizeLarge
                            font.bold: true
                            color: "white"
                            text: modelData.key === "ap" ? "AP" : modelData.name.charAt(0)
                        }
                    }

                    Column {
                        id: texts
                        anchors {
                            left: badge.right; leftMargin: Theme.paddingLarge
                            right: parent.right; rightMargin: Theme.horizontalPageMargin
                        }
                        y: Theme.paddingLarge
                        spacing: Theme.paddingSmall / 2

                        Label {
                            width: parent.width
                            truncationMode: TruncationMode.Fade
                            font.pixelSize: Theme.fontSizeLarge
                            color: tile.highlighted ? Theme.highlightColor : Theme.primaryColor
                            text: modelData.full
                        }
                        Label {
                            width: parent.width
                            truncationMode: TruncationMode.Fade
                            font.pixelSize: Theme.fontSizeExtraSmall
                            color: Theme.secondaryHighlightColor
                            text: modelData.about + " · " + modelData.categories.length
                                  + (modelData.categories.length === 1 ? " category" : " categories")
                        }
                        Label {
                            width: parent.width
                            visible: text !== ""
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                            font.pixelSize: Theme.fontSizeSmall
                            color: tile.highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
                            text: tile.latest ? tile.latest.title : ""
                        }
                        Label {
                            width: parent.width
                            visible: text !== ""
                            font.pixelSize: Theme.fontSizeExtraSmall
                            color: Theme.secondaryColor
                            text: tile.latest ? Rss.relativeTime(tile.latest.date, page.now)
                                              : "Tap to load the news"
                        }
                    }
                }
            }

            Item { width: 1; height: Theme.paddingLarge }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                text: "Tap a source for its news, and a story to read it whole."
            }
        }
    }
}
