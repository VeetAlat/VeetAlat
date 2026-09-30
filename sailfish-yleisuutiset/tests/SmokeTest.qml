import QtQuick 2.0
import Sailfish.Silica 1.0

// Injected into a copy of the app by tests/sdk-smoke-test.sh (never
// shipped). The app runs without a window against local fixture feeds,
// so real HTTP fetches (feeds and pictures) happen. Checks the app's real
// page from its page stack. Run 1 fetches; run 2 (a restart) checks the
// category is remembered and cached news shows before any fetch.
Item {
    id: smoke

    property var testedWindow
    property var testedNews
    property int failures: 0
    property int step: 0
    property bool secondRun: false
    property var page
    property string realBase

    function check(name, ok) {
        console.log((ok ? "SMOKE PASS " : "SMOKE FAIL ") + name)
        if (!ok) failures++
    }
    function finish() {
        ticker.stop()
        console.log("SMOKE DONE failures=" + failures)
        Qt.quit()
    }

    // Visible article pictures that finished loading.
    function loadedPictures(item) {
        var n = 0
        if (!item) return 0
        if (item.hasOwnProperty("status") && item.hasOwnProperty("sourceSize")
                && item.status === Image.Ready && String(item.source) !== "") n++
        var kids = item.children || []
        for (var i = 0; i < kids.length; i++) n += loadedPictures(kids[i])
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
            if (!smoke.page) {
                smoke.page = smoke.testedWindow.pageStack.currentPage
                if (!smoke.page) return
                smoke.realBase = n.feedBase
                // Run 1 ends on "kotimaa", so seeing it here means a restart.
                smoke.secondRun = n.categoryKey === "kotimaa"
                console.log(smoke.secondRun ? "SMOKE RUN 2" : "SMOKE RUN 1")
                if (smoke.secondRun) {
                    smoke.check("last category remembered", n.categoryKey === "kotimaa")
                    smoke.check("cached news shown at start", n.items.length === 2 && n.fromCache)
                }
                smoke.check("main page gets the app's news", smoke.page.news === n)
                if (smoke.secondRun) {
                    smoke.check("fresh cache isn't fetched again", !n.loading)
                    n.select("main")
                    smoke.check("switching shows that category's cache at once",
                                n.categoryKey === "main" && n.items.length === 4)
                    smoke.finish()
                    return
                }
                smoke.check("first start begins on the front page", n.categoryKey === "main")
                // The page asks for news as soon as it's built; by now the
                // fetch may already be done.
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
                smoke.check("front page has 4 articles", n.items.length === 4)
                smoke.check("headline text", n.items.length > 0 && n.items[0].title.indexOf("Hallitus esittää") === 0)
                smoke.check("picture address found", n.items.length > 0 && n.items[0].image.indexOf("39-100001.jpg") > 0)
                smoke.check("live news, not cache", !n.fromCache && n.fetched > 0)
                break
            case 1:
                // Give the pictures a moment, then open an article on the real page stack.
                smoke.check("article pictures load", smoke.loadedPictures(smoke.page) >= 2)
                var article = smoke.testedWindow.pageStack.push(Qt.resolvedUrl("pages/ArticlePage.qml"),
                                                                { article: n.items[0] }, PageStackAction.Immediate)
                smoke.check("article page opens", article !== null && article.article.link === n.items[0].link)
                smoke.testedWindow.pageStack.pop(null, PageStackAction.Immediate)
                var cats = smoke.testedWindow.pageStack.push(Qt.resolvedUrl("pages/CategoriesPage.qml"),
                                                             { news: n }, PageStackAction.Immediate)
                smoke.check("categories page opens", cats !== null)
                smoke.testedWindow.pageStack.pop(null, PageStackAction.Immediate)
                smoke.check("back on the main page", smoke.testedWindow.pageStack.currentPage === smoke.page)
                n.select("kotimaa")
                smoke.check("choosing a category fetches it", n.loading && n.categoryKey === "kotimaa")
                break
            case 2:
                smoke.check("category loads", n.error === "" && n.items.length === 2)
                // Point at a feed that doesn't exist: an error, but the news stays.
                n.feedBase = smoke.realBase + "missing/"
                n.refresh()
                break
            case 3:
                smoke.check("server error is reported", n.error.indexOf("404") >= 0)
                smoke.check("news stays visible after an error", n.items.length === 2)
                n.feedBase = smoke.realBase
                smoke.finish()
                break
            }
        }
    }
}
