import QtQuick 2.0
import Sailfish.Silica 1.0

// Injected into a copy of the app by tests/sdk-smoke-test.sh (never
// shipped). The app runs without a window against local fixture feeds, so
// real HTTP fetches happen. Uses the app's real page stack. Run 1 fetches;
// run 2 (a restart) checks the category is remembered, cached headlines
// show before any fetch, and "Delete saved headlines" empties the cache.
//
// The fixture feeds contain photos and summaries on purpose: Yle's RSS
// terms allow only headlines linking to yle.fi, so the app must drop them.
Item {
    id: smoke

    property var testedWindow
    property var testedNews
    property int failures: 0
    property int step: 0
    property bool secondRun: false
    property var page
    property string realBase
    property string openedLink: ""

    function check(name, ok) {
        console.log((ok ? "SMOKE PASS " : "SMOKE FAIL ") + name)
        if (!ok) failures++
    }
    function finish() {
        ticker.stop()
        console.log("SMOKE DONE failures=" + failures)
        Qt.quit()
    }

    // Only headline fields, nothing else from the feed.
    function headlinesOnly(items) {
        for (var i = 0; i < items.length; i++) {
            var keys = Object.keys(items[i]).sort().join(",")
            if (keys !== "categories,date,id,link,title") return false
        }
        return items.length > 0
    }

    // Every headline row on the page (ArticleItem has "article" and "leading").
    function headlineRows(item, out) {
        if (!item) return out
        if (item.hasOwnProperty("article") && item.hasOwnProperty("leading")) out.push(item)
        var kids = item.children || []
        for (var i = 0; i < kids.length; i++) headlineRows(kids[i], out)
        return out
    }

    // Any Image with a picture on the page.
    function pictures(item) {
        var n = 0
        if (!item) return 0
        if (item.hasOwnProperty("sourceSize") && item.hasOwnProperty("fillMode")
                && String(item.source).indexOf("http") === 0) n++
        var kids = item.children || []
        for (var i = 0; i < kids.length; i++) n += pictures(kids[i])
        return n
    }

    // Checks start on the first timer tick: this object and the news store
    // are siblings, and Qt doesn't promise which finishes starting first.
    Component.onCompleted: ticker.start()

    Timer {
        id: ticker
        interval: 100
        repeat: true
        property int waited: 0
        onTriggered: {
            var n = smoke.testedNews
            var stack = smoke.testedWindow.pageStack
            if (!smoke.page) {
                smoke.page = stack.currentPage
                if (!smoke.page) return
                smoke.page.openLink = function(link) { smoke.openedLink = link }
                smoke.realBase = n.feedBase
                // Run 1 ends on "kotimaa", so seeing it here means a restart.
                smoke.secondRun = n.categoryKey === "kotimaa"
                console.log(smoke.secondRun ? "SMOKE RUN 2" : "SMOKE RUN 1")
                smoke.check("main page gets the app's news", smoke.page.news === n)
                if (smoke.secondRun) {
                    smoke.check("last category remembered", n.categoryKey === "kotimaa")
                    smoke.check("cached headlines shown at start", n.items.length === 2 && n.fromCache)
                    smoke.check("list starts at the very top", smoke.page.atTop)
                    smoke.check("cache holds headlines only", smoke.headlinesOnly(n.items))
                    smoke.check("fresh cache isn't fetched again", !n.loading)
                    n.select("main")
                    smoke.check("switching shows that category's cache at once",
                                n.categoryKey === "main" && n.items.length === 4)

                    // The About page's "Delete saved headlines" button calls this.
                    n.clearSaved()
                    smoke.check("'Delete saved headlines' empties the list", n.items.length === 0)
                    n.select("kotimaa")
                    smoke.check("deleted headlines are gone from storage too",
                                n.items.length === 0 && !n.fromCache)
                    smoke.finish()
                    return
                }
                smoke.check("first start begins on the front page", n.categoryKey === "main")
                smoke.check("first start fetches right away", n.loading || n.fetched > 0)
                return
            }
            if (n.loading) {
                if (++waited > 150) { smoke.check("fetch finished in time", false); smoke.finish() }
                return
            }
            waited = 0
            switch (smoke.step++) {
            case 0:
                smoke.check("front page loads without error", n.error === "")
                smoke.check("front page has 4 headlines", n.items.length === 4)
                smoke.check("headline text", n.items.length > 0 && n.items[0].title.indexOf("Hallitus esittää") === 0)
                smoke.check("photos and summaries dropped, headlines only", smoke.headlinesOnly(n.items))
                smoke.check("live headlines, not cache", !n.fromCache && n.fetched > 0)
                smoke.check("list is scrolled to the very top after loading", smoke.page.atTop)
                // "Hot": the first two headlines, while under six hours old.
                var fresh = { date: Date.now() - 3600000 }, stale = { date: Date.now() - 8 * 3600000 }
                smoke.check("first two fresh headlines are hot",
                            smoke.page.isHot(0, fresh) && smoke.page.isHot(1, fresh))
                smoke.check("third headline isn't hot", !smoke.page.isHot(2, fresh))
                smoke.check("old headlines aren't hot", !smoke.page.isHot(0, stale))
                // The cover shows each headline's date and time, e.g. "30.9. 12:03".
                var cover = smoke.testedWindow.cover.createObject(smoke, { news: n })
                smoke.check("cover shows date and time",
                            /^\d{1,2}\.\d{1,2}\. \d{2}:\d{2}$/.test(cover.articleTime))
                break
            case 1:
                var rows = smoke.headlineRows(smoke.page, [])
                // A list only builds the rows that fit on screen, and without a
                // window that's very few; the first headline is always there.
                smoke.check("headline rows shown", rows.length >= 1)
                smoke.check("no pictures on the page", smoke.pictures(smoke.page) === 0)
                // Tap the first headline: it must open that story on yle.fi.
                var first = null
                for (var i = 0; i < rows.length; i++) if (rows[i].leading) first = rows[i]
                if (first) first.clicked(null)
                smoke.check("tapping a headline opens its story on yle.fi",
                            smoke.openedLink === "https://yle.fi/a/74-20100001")

                var about = stack.push(Qt.resolvedUrl("pages/AboutPage.qml"), { news: n },
                                       PageStackAction.Immediate)
                smoke.check("about page opens", about !== null)
                smoke.check("made by Valatalo", about.author === "Valatalo")
                smoke.check("no OpenRepos link until one is set", about.openReposUrl === "")
                stack.pop(null, PageStackAction.Immediate)
                smoke.check("back on the main page", stack.currentPage === smoke.page)

                n.select("kotimaa")
                smoke.check("choosing a category fetches it", n.loading && n.categoryKey === "kotimaa")
                break
            case 2:
                smoke.check("category loads", n.error === "" && n.items.length === 2)
                // Point at a feed that doesn't exist: an error, but the headlines stay.
                n.feedBase = smoke.realBase + "missing/"
                n.refresh()
                break
            case 3:
                smoke.check("server error is reported", n.error.indexOf("404") >= 0)
                smoke.check("headlines stay visible after an error", n.items.length === 2)
                n.feedBase = smoke.realBase
                smoke.finish()
                break
            }
        }
    }
}
