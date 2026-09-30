import QtQuick 2.0
import "../js/rss.js" as Rss
import "../js/feeds.js" as Feeds
import "../js/cache.js" as Cache

// Fetches Yle's RSS feeds, keeps the current category's headlines, and
// caches every fetched feed so the app starts instantly and works offline.
//
// Yle's RSS terms (yle.fi/aihe/a/20-10008076) allow showing headlines that
// each link straight to the story on Yle's site, and forbid copying other
// content or using the stories' photos. So only headline, link, time and
// category are kept; pictures and summaries in the feed are dropped here,
// before anything is shown or saved.
// There is one, created in the main QML file as "newsStore".
QtObject {
    id: store

    // Overridable feed address (tests point it at local fixtures).
    property string feedBase: Feeds.DEFAULT_BASE

    property string categoryKey: "main"
    readonly property var category: Feeds.byKey(categoryKey)
    readonly property var categories: Feeds.categories

    property var items: []          // headlines: [{ title, link, date, categories, id }]
    property real fetched: 0        // when they were fetched (ms), 0 = never
    property bool loading: false
    property string error: ""       // last fetch problem, "" if none
    property bool fromCache: false  // items are cached, the latest fetch failed or is pending

    // Fetch again when older than this.
    property int maxAgeMs: 5 * 60 * 1000
    property int timeoutMs: 20000

    property var _request: null

    function select(key) {
        var cat = Feeds.byKey(key)
        if (cat.key === categoryKey && items.length > 0) {
            refreshIfStale()
            return
        }
        categoryKey = cat.key
        try { Cache.setSetting("category", cat.key) } catch (e) { }
        showCached()
        refreshIfStale()
    }

    // Only what the terms allow: the headline and where it leads.
    function headlinesOnly(articles) {
        var out = []
        for (var i = 0; i < articles.length; i++) {
            var a = articles[i]
            out.push({ title: a.title, link: a.link, date: a.date,
                       categories: a.categories || [], id: a.id })
        }
        return out
    }

    // Deletes every saved headline (Yle may ask users to delete the
    // content; this does it in one go).
    function clearSaved() {
        try { Cache.clearFeeds() } catch (e) { }
        items = []
        fetched = 0
        fromCache = false
    }

    function showCached() {
        var cached = null
        try { cached = Cache.feed(categoryKey) } catch (e) { }
        items = cached ? headlinesOnly(cached.items) : []
        fetched = cached ? cached.fetched : 0
        fromCache = !!cached
        error = ""
    }

    function refreshIfStale() {
        if (!loading && (items.length === 0 || Date.now() - fetched > maxAgeMs)) refresh()
    }

    function refresh() {
        if (_request) _request.abort()
        var key = categoryKey
        var xhr = new XMLHttpRequest()
        _request = xhr
        loading = true
        error = ""
        timeout.restart()

        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE || xhr !== _request) return
            _request = null
            timeout.stop()
            loading = false
            if (key !== categoryKey) return // switched category meanwhile

            if (xhr.status !== 200) {
                error = xhr.status === 0 ? "No connection to Yle."
                                         : "Yle answered with error " + xhr.status + "."
                return
            }
            var feed
            try {
                feed = Rss.parse(xhr.responseText)
            } catch (e) {
                error = "Yle's feed couldn't be read (" + e.message + ")."
                return
            }
            items = headlinesOnly(feed.items)
            fetched = Date.now()
            fromCache = false
            try { Cache.saveFeed(key, fetched, items) } catch (e2) { }
        }
        xhr.open("GET", Feeds.url(category, feedBase))
        xhr.send()
    }

    property Timer timeout: Timer {
        interval: store.timeoutMs
        onTriggered: {
            if (store._request) {
                var r = store._request
                store._request = null
                r.abort()
                store.loading = false
                store.error = "Yle didn't answer in time."
            }
        }
    }

    function load() {
        var saved = "main"
        try { saved = Cache.setting("category", "main") } catch (e) { }
        categoryKey = Feeds.byKey(saved).key
        showCached()
    }

    Component.onCompleted: load()
}
