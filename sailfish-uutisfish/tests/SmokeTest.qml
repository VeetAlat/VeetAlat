import QtQuick 2.0
import Sailfish.Silica 1.0

// Injected into a copy of the app by tests/sdk-smoke-test.sh (never
// shipped). The app runs without a window against local fixture feeds, so
// real HTTP fetches happen. Uses the app's real page stack.
//
// Run 1 starts on the home page and goes through all three sources: Yle
// (headlines, a story with its text and photos, a missing story, another
// category, a feed error), MTV Uutiset (a story built from the page's
// data) and AP News (a story in plain <div>s). It ends on AP.
// Run 2 (a restart) checks the last category is remembered, the home page
// shows each source's saved headline, each source reopens on the category
// last read there, and "Delete saved news" empties the cache.
Item {
    id: smoke

    property var testedWindow
    property var testedNews
    property int failures: 0
    property int step: 0
    property bool secondRun: false
    property var home
    property var page
    property var storyPage
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

    // Each story keeps its summary and photo from the feed.
    function storiesKept(items) {
        for (var i = 0; i < items.length; i++) {
            var keys = Object.keys(items[i]).sort().join(",")
            if (keys !== "categories,date,id,image,link,summary,title") return false
        }
        return items.length > 0
    }
    // Waits (up to 15 s) for cond; false while still waiting.
    function ready(cond, what) {
        if (cond) { ticker.waited = 0; return true }
        if (++ticker.waited > 150) { check(what + " in time", false); finish(); return false }
        step--
        return false
    }
    function kinds(blocks) {
        return blocks.map(function(b) { return b.type }).join(",")
    }

    // Every headline row on the page (ArticleItem has "article" and "leading").
    function headlineRows(item, out) {
        if (!item) return out
        if (item.hasOwnProperty("article") && item.hasOwnProperty("leading")) out.push(item)
        var kids = item.children || []
        for (var i = 0; i < kids.length; i++) headlineRows(kids[i], out)
        return out
    }

    // Images on the page with a picture from the web; only loaded ones if asked.
    function pictures(item, loadedOnly) {
        var n = 0
        if (!item) return 0
        if (item.hasOwnProperty("sourceSize") && item.hasOwnProperty("fillMode")
                && String(item.source).indexOf("http") === 0
                && (!loadedOnly || item.status === Image.Ready)) n++
        var kids = item.children || []
        for (var i = 0; i < kids.length; i++) n += pictures(kids[i], loadedOnly)
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
            if (!smoke.home) {
                smoke.home = stack.currentPage
                if (!smoke.home) return
                smoke.home.openLink = function(link) { smoke.openedLink = link }
                smoke.realBase = n.feedBase
                // Run 1 ends on AP's top stories, so seeing it here means a restart.
                smoke.secondRun = n.categoryKey === "ap/top"
                console.log(smoke.secondRun ? "SMOKE RUN 2" : "SMOKE RUN 1")
                smoke.check("the app opens on the home page", smoke.home.hasOwnProperty("revision"))
                smoke.check("home page gets the app's news", smoke.home.news === n)
                smoke.check("three sources on the home page",
                            n.sources.length === 3 && n.sources[0].full === "Yle Uutiset"
                            && n.sources[1].full === "MTV Uutiset" && n.sources[2].full === "AP News")
                if (smoke.secondRun) {
                    smoke.check("last category remembered", n.categoryKey === "ap/top" && n.source.key === "ap")
                    smoke.check("its saved headlines are there at start", n.items.length === 3 && n.fromCache)
                    smoke.check("cache keeps summaries and photos", smoke.storiesKept(n.items))
                    smoke.check("the home page doesn't fetch anything", !n.loading)
                    var yle = n.latestSaved("yle"), mtv = n.latestSaved("mtv"), ap = n.latestSaved("ap")
                    smoke.check("home: Yle's newest saved headline, from the category last read there",
                                yle !== null && yle.title === "Juna-liikenteessä häiriöitä Tampereella")
                    smoke.check("home: MTV's newest saved headline",
                                mtv !== null && mtv.title === "Helsingissä avattiin uusi metroasema")
                    smoke.check("home: AP's newest saved headline",
                                ap !== null && ap.title.indexOf("City council passes a budget") === 0)

                    n.openSource("yle")
                    smoke.check("Yle reopens on the category last read there",
                                n.categoryKey === "yle/kotimaa" && n.items.length === 2 && n.fromCache)
                    smoke.check("fresh saved news isn't fetched again", !n.loading)
                    n.openSource("mtv")
                    smoke.check("MTV reopens on its news, saved", n.categoryKey === "mtv/main" && n.items.length === 2)
                    n.select("yle/main")
                    smoke.check("switching shows that category's saved news at once",
                                n.categoryKey === "yle/main" && n.items.length === 4)

                    // The About page's "Delete saved news" button calls this.
                    n.clearSaved()
                    smoke.check("'Delete saved news' empties the list", n.items.length === 0)
                    smoke.check("and every source's saved headlines",
                                n.latestSaved("yle") === null && n.latestSaved("mtv") === null
                                && n.latestSaved("ap") === null)
                    smoke.finish()
                    return
                }
                smoke.check("first start remembers nothing yet", n.categoryKey === "yle/main" && n.items.length === 0)
                smoke.check("the home page doesn't fetch anything", !n.loading && n.fetched === 0)
                smoke.check("home tiles invite a first load", n.latestSaved("yle") === null)

                smoke.page = smoke.home.open("yle")
                smoke.check("tapping Yle opens its headlines",
                            smoke.page !== smoke.home && n.source.key === "yle" && n.categoryKey === "yle/main")
                smoke.check("and fetches them right away", n.loading || n.fetched > 0)
                return
            }
            if (n.loading) {
                if (++waited > 150) { smoke.check("fetch finished in time", false); smoke.finish() }
                return
            }
            waited = 0
            switch (smoke.step++) {
            // --- Yle ---
            case 0:
                smoke.check("Yle's front page loads without error", n.error === "")
                smoke.check("Yle's front page has 4 headlines", n.items.length === 4)
                smoke.check("headline text", n.items.length > 0 && n.items[0].title.indexOf("Hallitus esittää") === 0)
                smoke.check("stories keep their summaries and photos", smoke.storiesKept(n.items))
                smoke.check("live headlines, not saved ones", !n.fromCache && n.fetched > 0)
                smoke.check("Yle's 13 category buttons", n.categories.length === 13)
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
                if (!smoke.ready(!stack.busy, "Yle's page shown")) break
                var rows = smoke.headlineRows(smoke.page, [])
                // A list only builds the rows that fit on screen, and without a
                // window that's very few; the first headline is always there.
                smoke.check("headline rows shown", rows.length >= 1)
                smoke.check("rows name their source", rows.length > 0 && rows[0].source.key === "yle")
                smoke.check("no pictures in the headline list", smoke.pictures(smoke.page, false) === 0)
                // Tap the first headline: its whole story opens in the app.
                var first = null
                for (var i = 0; i < rows.length; i++) if (rows[i].leading) first = rows[i]
                if (first) first.clicked(null)
                smoke.storyPage = stack.currentPage
                smoke.check("tapping a headline opens the story in the app",
                            smoke.storyPage !== smoke.page && smoke.storyPage.story !== undefined
                            && smoke.storyPage.story.link === "https://yle.fi/a/74-20100001"
                            && smoke.openedLink === "")
                smoke.check("the feed's headline and summary show at once",
                            smoke.storyPage.title === n.items[0].title && smoke.storyPage.lead === n.items[0].summary)
                smoke.check("the story page knows its site", smoke.storyPage.site === "yle.fi")
                break
            case 2:
                var sp = smoke.storyPage
                if (!smoke.ready(!sp.loading, "Yle story loaded")) break
                smoke.check("the story loads without error", sp.error === "" && sp.hasText)
                smoke.check("its text came from its page", sp.article.source === "page")
                smoke.check("headline and lead from the story's page",
                            sp.title === "Hallitus esittää muutoksia työttömyysturvaan"
                            && sp.lead === "Esitys lähtee lausuntokierrokselle ensi viikolla.")
                smoke.check("the whole story in order: photo, text, subheading, text, photo, text",
                            smoke.kinds(sp.blocks) === "image,text,heading,text,image,text")
                smoke.check("photo caption", sp.blocks[0].caption === "Ministeri esitteli muutokset tiistaina.")
                smoke.check("no page furniture in the text", sp.blocks.every(function(b) {
                    return !/Etusivu|ei tekstiä|©/.test(b.text || "") }))
                break
            case 3:
                var sp3 = smoke.storyPage
                if (!smoke.ready(smoke.pictures(sp3, true) >= 2 && !stack.busy, "Yle story photos loaded")) break
                smoke.check("the story's photos load", smoke.pictures(sp3, true) === 2)
                smoke.check("the story is kept for next time", n.cachedArticle(sp3.story.link) !== null)
                stack.pop(null, PageStackAction.Immediate)
                // The second story's page is missing on purpose.
                smoke.storyPage = smoke.page.read(n.items[1])
                break
            case 4:
                var sp4 = smoke.storyPage
                if (!smoke.ready(!sp4.loading && !stack.busy, "missing story answered")) break
                smoke.check("a missing story says why", sp4.error.indexOf("404") >= 0 && !sp4.hasText)
                smoke.check("and shows the feed's headline, summary and photo instead",
                            sp4.title === n.items[1].title && sp4.lead === n.items[1].summary
                            && sp4.blocks.length === 1 && sp4.blocks[0].src === n.items[1].image)
                var report = sp4.pageReport()
                smoke.check("a page report can be copied for fixing",
                            report.indexOf("UutisFish page report") === 0 && report.indexOf("status: 404") > 0)
                stack.pop(null, PageStackAction.Immediate)
                smoke.check("back on Yle's headlines", stack.currentPage === smoke.page)

                var about = stack.push(Qt.resolvedUrl("pages/AboutPage.qml"), { news: n },
                                       PageStackAction.Immediate)
                smoke.check("about page opens", about !== null)
                smoke.check("made by Valatalo", about.author === "Valatalo")
                stack.pop(null, PageStackAction.Immediate)

                n.select("yle/kotimaa")
                smoke.check("choosing a category fetches it", n.loading && n.categoryKey === "yle/kotimaa")
                break
            case 5:
                smoke.check("category loads", n.error === "" && n.items.length === 2)
                // Point at a feed that doesn't exist: an error, but the headlines stay.
                n.feedBase = smoke.realBase + "missing/"
                n.refresh()
                break
            case 6:
                smoke.check("server error is reported, naming the source",
                            n.error.indexOf("404") >= 0 && n.error.indexOf("Yle Uutiset") === 0)
                smoke.check("headlines stay visible after an error", n.items.length === 2)
                n.feedBase = smoke.realBase
                // --- MTV Uutiset ---
                stack.pop(smoke.home, PageStackAction.Immediate)
                smoke.check("back on the home page", stack.currentPage === smoke.home)
                smoke.page = smoke.home.open("mtv")
                smoke.check("tapping MTV Uutiset opens its news", n.source.key === "mtv" && n.categoryKey === "mtv/main")
                break
            case 7:
                if (!smoke.ready(!stack.busy, "MTV's page shown")) break
                smoke.check("MTV's news loads", n.error === "" && n.items.length === 2
                            && n.items[0].title === "Helsingissä avattiin uusi metroasema")
                smoke.check("MTV's 2 category buttons", n.categories.length === 2)
                smoke.storyPage = smoke.page.read(n.items[0])
                smoke.check("an MTV story knows its site", smoke.storyPage.site === "mtvuutiset.fi")
                break
            case 8:
                var spm = smoke.storyPage
                if (!smoke.ready(!spm.loading && !stack.busy, "MTV story loaded")) break
                smoke.check("MTV story: read from the page's data", spm.error === "" && spm.article.source === "data")
                smoke.check("MTV story in order: photo, text, text, subheading, photo, text, text",
                            smoke.kinds(spm.blocks) === "image,text,text,heading,image,text,text")
                smoke.check("MTV story: photo caption from the data", spm.blocks[4].caption === "Asema avattiin aamulla.")
                // --- AP News ---
                stack.pop(smoke.home, PageStackAction.Immediate)
                smoke.page = smoke.home.open("ap")
                smoke.check("tapping AP News opens its top stories", n.source.key === "ap" && n.categoryKey === "ap/top")
                break
            case 9:
                if (!smoke.ready(!stack.busy, "AP's page shown")) break
                smoke.check("AP's top stories load", n.error === "" && n.items.length === 3
                            && n.items[0].title.indexOf("City council passes a budget") === 0)
                smoke.check("AP's 10 category buttons", n.categories.length === 10)
                smoke.storyPage = smoke.page.read(n.items[0])
                smoke.check("an AP story knows its site", smoke.storyPage.site === "apnews.com")
                break
            case 10:
                var spa = smoke.storyPage
                if (!smoke.ready(!spa.loading && !stack.busy, "AP story loaded")) break
                smoke.check("AP story: read from its page", spa.error === "" && spa.article.source === "page")
                smoke.check("AP story in order: photo, text, text, subheading, text, text",
                            smoke.kinds(spa.blocks) === "image,text,text,heading,text,text")
                smoke.check("AP story: no links to other stories", spa.blocks.every(function(b) {
                    return b.text !== "Other story" }))
                break
            case 11:
                if (!smoke.ready(smoke.pictures(smoke.storyPage, true) >= 1, "AP story photo loaded")) break
                smoke.check("AP story's photo loads", smoke.pictures(smoke.storyPage, true) === 1)
                smoke.finish()
                break
            }
        }
    }
}
