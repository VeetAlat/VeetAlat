import QtQuick 2.0
import "../js/rss.js" as Rss
import "../js/feeds.js" as Feeds
import "../js/cache.js" as Cache

// Fetches the news sources' RSS feeds (Yle, MTV Uutiset, AP News), keeps
// the current category's stories, and caches every fetched feed so the app
// starts instantly and works offline. The current category decides the
// current source.
// Each story keeps its summary and photo from the feed too: the story page
// shows them at once while it fetches the whole story.
// There is one, created in the main QML file as "newsStore".
QtObject {
    id: store

    // Overridable feed address (tests point it at local fixtures).
    property string feedBase: Feeds.DEFAULT_BASE

    property string categoryKey: "yle/main"
    readonly property var category: Feeds.byKey(categoryKey)
    readonly property var source: Feeds.source(categoryKey)
    readonly property var sources: Feeds.sources
    readonly property var categories: source.categories

    property var items: []          // stories: [{ title, link, date, categories, id, summary, image }]
    property real fetched: 0        // when they were fetched (ms), 0 = never
    property bool loading: false
    property string error: ""       // last fetch problem, "" if none
    property bool fromCache: false  // items are cached, the latest fetch failed or is pending

    // Where stories are fetched from: their own address, unless set
    // (tests point it at local pages).
    property string articleBase: ""

    function articleUrl(link) {
        return articleBase === "" ? link : articleBase + String(link).replace(/^https?:\/\/[^\/]+\//, "")
    }

    // Stories read this session, so going back to one is instant. Only the
    // latest 30, in memory.
    property var _articles: ({})
    property var _articleOrder: []

    function cachedArticle(link) {
        return _articles.hasOwnProperty(link) ? _articles[link] : null
    }
    function keepArticle(link, article) {
        if (!_articles.hasOwnProperty(link)) _articleOrder.push(link)
        _articles[link] = article
        while (_articleOrder.length > 30) delete _articles[_articleOrder.shift()]
    }
    // Sites that answered the reader with a browser check, this session:
    // their stories then show the feed's summary at once.
    property var _blockedSites: ({})
    function isBlocked(site) { return _blockedSites.hasOwnProperty(site) }
    function markBlocked(site, blocked) {
        if (blocked) _blockedSites[site] = true
        else delete _blockedSites[site]
    }

    function forgetArticle(link) {
        delete _articles[link]
        var i = _articleOrder.indexOf(link)
        if (i >= 0) _articleOrder.splice(i, 1)
    }

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
        try {
            Cache.setSetting("category", cat.key)
            Cache.setSetting("category/" + Feeds.source(cat.key).key, cat.key)
        } catch (e) { }
        showCached()
        refreshIfStale()
    }

    // Opens a source on the category last read there, else its first.
    function openSource(key) {
        var src = Feeds.source(key)
        var last = src.categories[0].key
        try { last = Cache.setting("category/" + src.key, last) } catch (e) { }
        select(Feeds.byKey(last).key)
    }

    // The newest saved headline of a source, for the home page: from the
    // category last read there, else its first. null if none is saved.
    function latestSaved(key) {
        var src = Feeds.source(key)
        var keys = [src.categories[0].key]
        try { keys.unshift(Cache.setting("category/" + src.key, keys[0])) } catch (e) { }
        for (var i = 0; i < keys.length; i++) {
            var cached = null
            try { cached = Cache.feed(keys[i]) } catch (e2) { }
            if (cached && cached.items.length > 0) return cached.items[0]
        }
        return null
    }

    // What's kept of each story in the feed.
    function stories(articles) {
        var out = []
        for (var i = 0; i < articles.length; i++) {
            var a = articles[i]
            out.push({ title: a.title, link: a.link, date: a.date,
                       categories: a.categories || [], id: a.id,
                       summary: a.summary || "", image: a.image || "" })
        }
        return out
    }

    // Deletes every saved story list.
    function clearSaved() {
        try { Cache.clearFeeds() } catch (e) { }
        items = []
        fetched = 0
        fromCache = false
    }

    function showCached() {
        var cached = null
        try { cached = Cache.feed(categoryKey) } catch (e) { }
        items = cached ? stories(cached.items) : []
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
                error = xhr.status === 0 ? "No connection to " + source.full + "."
                                         : source.full + " answered with error " + xhr.status + "."
                return
            }
            var feed
            try {
                feed = Rss.parse(xhr.responseText)
            } catch (e) {
                error = source.full + "'s feed couldn't be read (" + e.message + ")."
                return
            }
            items = stories(feed.items)
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
                store.error = store.source.full + " didn't answer in time."
            }
        }
    }

    function load() {
        var saved = "yle/main"
        try { saved = Cache.setting("category", saved) } catch (e) { }
        categoryKey = Feeds.byKey(saved).key
        showCached()
    }

    Component.onCompleted: load()
}
