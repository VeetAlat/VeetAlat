import QtQuick 2.0
import Sailfish.Silica 1.0
import "../components"
import "../js/rss.js" as Rss

// Yle's news for the chosen category. Category buttons along the top;
// pull down for all categories and refresh; tap an article to read it.
Page {
    id: page

    property NewsStore news

    allowedOrientations: Orientation.All

    // Keeps "5 min ago" labels current.
    property real now: Date.now()
    Timer {
        interval: 60000
        repeat: true
        running: Qt.application.active
        triggeredOnStart: true
        onTriggered: page.now = Date.now()
    }

    // Fetch when the app comes back to the foreground with old news.
    Connections {
        target: Qt.application
        onActiveChanged: if (Qt.application.active && page.news) page.news.refreshIfStale()
    }
    Component.onCompleted: if (news) news.refreshIfStale()

    function openCategories() {
        pageStack.push(Qt.resolvedUrl("CategoriesPage.qml"), { news: page.news })
    }

    SilicaListView {
        id: list
        anchors.fill: parent
        model: page.news ? page.news.items : []

        PullDownMenu {
            busy: page.news !== null && page.news.loading
            MenuItem {
                text: "Open yle.fi in the browser"
                onClicked: Qt.openUrlExternally("https://yle.fi/")
            }
            MenuItem {
                text: "All categories"
                onClicked: page.openCategories()
            }
            MenuItem {
                text: "Refresh"
                onClicked: page.news.refresh()
            }
        }

        header: Column {
            width: list.width
            spacing: Theme.paddingMedium

            PageHeader {
                title: page.news ? page.news.category.name : ""
                description: "Yleisuutiset · " + (page.news ? page.news.category.english : "")
            }

            // Category buttons, scrolled so the current one is visible.
            ListView {
                id: chips
                width: parent.width
                height: Theme.itemSizeExtraSmall
                orientation: ListView.Horizontal
                spacing: Theme.paddingMedium
                leftMargin: Theme.horizontalPageMargin
                rightMargin: Theme.horizontalPageMargin
                clip: true
                model: page.news ? page.news.categories : []
                currentIndex: {
                    if (!page.news) return 0
                    for (var i = 0; i < page.news.categories.length; i++) {
                        if (page.news.categories[i].key === page.news.categoryKey) return i
                    }
                    return 0
                }
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                delegate: CategoryButton {
                    height: chips.height
                    text: modelData.name
                    selected: !!page.news && modelData.key === page.news.categoryKey
                    onClicked: page.news.select(modelData.key)
                }
            }

            // Status: loading, errors, or where the news came from.
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: page.news && page.news.error !== "" ? Theme.errorColor : Theme.secondaryColor
                text: {
                    if (!page.news) return ""
                    if (page.news.loading) return "Loading news from Yle…"
                    var when = page.news.fetched > 0 ? Rss.relativeTime(page.news.fetched, page.now) : ""
                    if (page.news.error !== "") {
                        return page.news.error + (page.news.items.length > 0
                                                  ? " Showing saved news from " + when + ". Pull down to try again."
                                                  : " Pull down to try again.")
                    }
                    return when ? "Updated " + when + " · pull down to refresh" : ""
                }
            }
        }

        delegate: ArticleItem {
            article: modelData
            hero: index === 0
            now: page.now
            onClicked: pageStack.push(Qt.resolvedUrl("ArticlePage.qml"), { article: modelData })
        }

        ViewPlaceholder {
            enabled: list.count === 0 && page.news !== null && !page.news.loading
            text: "No news to show"
            hintText: page.news && page.news.error !== "" ? page.news.error + " Pull down to try again."
                                                          : "Pull down to refresh"
        }

        BusyIndicator {
            anchors.centerIn: parent
            size: BusyIndicatorSize.Large
            running: list.count === 0 && page.news !== null && page.news.loading
        }

        VerticalScrollDecorator { }
    }
}
