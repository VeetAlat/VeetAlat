import QtQuick 2.0
import Sailfish.Silica 1.0
import "../js/rss.js" as Rss
import "../js/article.js" as Article

// One whole story, read inside the app: headline, time, lead, photos with
// their captions, subheadings and all the text. It shows the feed's
// headline, summary and photo at once, fetches the story's page from
// its site, and has it picked apart off the screen's thread (article.js via
// articleworker.js). Pull down to open it on its site instead.
Page {
    id: page

    property NewsStore news
    property var story            // the feed's story: { title, link, date, categories, summary, image }
    property var source: news ? news.source : null   // its news source, from feeds.js
    readonly property string site: source ? source.site : "the web"
    readonly property string sourceName: source ? source.full : "the news site"

    // Tests set this to see where a tap would go instead of opening the browser.
    property var openLink: function(link) { Qt.openUrlExternally(link) }

    property var article: null    // parseArticle's result, once there
    property bool loading: false
    property string error: ""
    readonly property bool hasText: article !== null && article.source !== "none"

    allowedOrientations: Orientation.All

    property var _request: null
    // What the story's address answered, kept only while its story isn't
    // found, for "Copy page report".
    property string _html: ""
    property int _status: 0
    property bool reportCopied: false
    // The site only lets web browsers open its stories.
    property bool blocked: false

    function pageReport() {
        return Article.articleReport(_html, news ? news.articleUrl(story.link) : story.link, _status)
    }

    function load() {
        error = ""
        reportCopied = false
        var cached = news ? news.cachedArticle(story.link) : null
        if (cached) {
            article = cached
            return
        }
        if (news && news.isBlocked(site)) {
            blocked = true
            return
        }
        blocked = false
        if (_request) _request.abort()
        var xhr = new XMLHttpRequest()
        _request = xhr
        loading = true
        timeout.restart()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE || xhr !== page._request) return
            page._request = null
            timeout.stop()
            page._status = xhr.status
            page._html = xhr.responseText || ""
            if (Article.articleBlocked(page._html, xhr.status)) {
                page.loading = false
                page.blocked = true
                if (page.news) page.news.markBlocked(page.site, true)
                return
            }
            if (xhr.status !== 200) {
                page.loading = false
                page.error = xhr.status === 0 ? "No connection to " + page.sourceName + "."
                                              : page.sourceName + " answered with error " + xhr.status + "."
                return
            }
            reader.sendMessage({ html: xhr.responseText, url: page.story.link })
        }
        xhr.open("GET", news ? news.articleUrl(story.link) : story.link)
        xhr.send()
    }

    WorkerScript {
        id: reader
        source: "../js/articleworker.js"
        onMessage: {
            if (messageObject.url !== page.story.link) return
            page.loading = false
            if (messageObject.error) {
                page.error = "The story couldn't be read (" + messageObject.error + ")."
                return
            }
            page.article = messageObject.article
            if (page.hasText) page._html = ""
            if (page.news && page.hasText) page.news.keepArticle(page.story.link, page.article)
        }
    }

    Timer {
        id: timeout
        interval: page.news ? page.news.timeoutMs : 20000
        onTriggered: {
            if (page._request) {
                var r = page._request
                page._request = null
                r.abort()
                page.loading = false
                page.error = page.sourceName + " didn't answer in time."
            }
        }
    }

    Component.onCompleted: load()

    // Until the story's here, what the feed had.
    readonly property string title: article && article.title ? article.title : story.title
    readonly property string lead: article && article.lead ? article.lead : story.summary
    readonly property var blocks: {
        if (hasText) return article.blocks
        return story.image ? [{ type: "image", src: story.image, caption: "" }] : []
    }
    readonly property string when: {
        var t = article && isFinite(article.published) ? article.published : story.date
        return Rss.relativeTime(t, Date.now())
    }

    SilicaFlickable {
        id: flick
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge * 2

        PullDownMenu {
            busy: page.loading
            MenuItem {
                text: "Open on " + page.site
                onClicked: page.openLink(page.story.link)
            }
            MenuItem {
                text: "Copy link"
                onClicked: Clipboard.text = page.story.link
            }
            MenuItem {
                // For fixing the reader: how the page is built, to paste to its maker.
                text: page.reportCopied ? "Page report copied" : "Copy page report"
                visible: !page.loading && !page.hasText && !page.blocked && page._status !== 0
                onClicked: {
                    Clipboard.text = page.pageReport()
                    page.reportCopied = true
                }
            }
            MenuItem {
                text: "Load again"
                visible: !page.loading
                onClicked: {
                    page.article = null
                    if (page.news) {
                        page.news.forgetArticle(page.story.link)
                        page.news.markBlocked(page.site, false)
                    }
                    page.load()
                }
            }
        }

        VerticalScrollDecorator { }

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingLarge

            PageHeader {
                title: page.story.categories.length > 0 ? page.story.categories[0] : page.sourceName
                description: page.when
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                textFormat: Text.PlainText
                font.pixelSize: Theme.fontSizeExtraLarge
                font.family: Theme.fontFamilyHeading
                color: Theme.highlightColor
                text: page.title
            }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: text !== ""
                wrapMode: Text.Wrap
                textFormat: Text.PlainText
                font.pixelSize: Theme.fontSizeMedium
                font.bold: true
                color: Theme.primaryColor
                text: page.lead
            }

            Repeater {
                model: page.blocks
                delegate: Loader {
                    width: column.width
                    property var block: modelData
                    sourceComponent: modelData.type === "image" ? imageBlock
                                   : modelData.type === "heading" ? headingBlock
                                   : modelData.type === "quote" ? quoteBlock
                                   : modelData.type === "item" ? itemBlock : textBlock
                }
            }

            // Loading, or why there's only the summary.
            BusyIndicator {
                anchors.horizontalCenter: parent.horizontalCenter
                size: BusyIndicatorSize.Medium
                running: page.loading
                visible: running
            }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: !page.loading && !page.hasText
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
                color: page.error !== "" ? Theme.errorColor : Theme.secondaryHighlightColor
                text: page.blocked
                      ? page.site + " only lets web browsers open its stories, so UutisFish can "
                        + "show just the summary from the feed. Open it on " + page.site
                        + " for the whole story."
                      : (page.error !== "" ? page.error
                                           : "The story's text couldn't be found on its page.")
                        + " Pull down to load it again or open it on " + page.site + ", or to copy "
                        + "a report on the page for fixing UutisFish."
            }
            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: !page.loading
                text: "Open on " + page.site
                onClicked: page.openLink(page.story.link)
            }
        }
    }

    Component {
        id: textBlock
        Label {
            x: Theme.horizontalPageMargin
            width: parent.width - 2 * x
            wrapMode: Text.Wrap
            textFormat: Text.PlainText
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.primaryColor
            text: block.text
        }
    }
    Component {
        id: headingBlock
        Label {
            x: Theme.horizontalPageMargin
            width: parent.width - 2 * x
            wrapMode: Text.Wrap
            textFormat: Text.PlainText
            font.pixelSize: Theme.fontSizeMedium
            font.bold: true
            color: Theme.highlightColor
            text: block.text
        }
    }
    Component {
        id: quoteBlock
        Item {
            width: parent.width
            height: quoteText.height
            Rectangle {
                x: Theme.horizontalPageMargin
                width: Theme.paddingSmall
                height: parent.height
                radius: width / 2
                color: Theme.highlightColor
            }
            Label {
                id: quoteText
                x: Theme.horizontalPageMargin + Theme.paddingLarge
                width: parent.width - x - Theme.horizontalPageMargin
                wrapMode: Text.Wrap
                textFormat: Text.PlainText
                font.pixelSize: Theme.fontSizeMedium
                font.italic: true
                color: Theme.highlightColor
                text: block.text
            }
        }
    }
    Component {
        id: itemBlock
        Item {
            width: parent.width
            height: itemText.height
            Label {
                x: Theme.horizontalPageMargin
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.highlightColor
                text: "•"
            }
            Label {
                id: itemText
                x: Theme.horizontalPageMargin + Theme.paddingLarge
                width: parent.width - x - Theme.horizontalPageMargin
                wrapMode: Text.Wrap
                textFormat: Text.PlainText
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.primaryColor
                text: block.text
            }
        }
    }
    Component {
        id: imageBlock
        Column {
            width: parent.width
            spacing: Theme.paddingSmall

            Item {
                width: parent.width
                // 3:2 while it loads, then the photo's own shape.
                height: photo.status === Image.Ready && photo.implicitWidth > 0
                        ? width * photo.implicitHeight / photo.implicitWidth : width * 2 / 3
                visible: photo.status !== Image.Error

                Rectangle {
                    anchors.fill: parent
                    visible: photo.status !== Image.Ready
                    color: Theme.rgba(Theme.highlightBackgroundColor, 0.15)
                }
                BusyIndicator {
                    anchors.centerIn: parent
                    size: BusyIndicatorSize.Small
                    running: photo.status === Image.Loading
                }
                Image {
                    id: photo
                    anchors.fill: parent
                    asynchronous: true
                    fillMode: Image.PreserveAspectFit
                    sourceSize.width: width
                    smooth: true
                    source: block.src
                }
            }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: block.caption !== "" && photo.status !== Image.Error
                wrapMode: Text.Wrap
                textFormat: Text.PlainText
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                text: block.caption
            }
        }
    }
}
