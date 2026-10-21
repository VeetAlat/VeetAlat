// Unit tests for qml/js/rss.js and feeds.js. Run: node tests/test_rss.js
const fs = require("fs")
const path = require("path")
const vm = require("vm")

function load(file) {
    const src = fs.readFileSync(path.join(__dirname, "../qml/js", file), "utf8")
        .replace(/^\.pragma library\s*$/m, "")
    const ctx = {}
    vm.createContext(ctx)
    vm.runInContext(src, ctx)
    return { ctx, src }
}
const { ctx: R, src: rssSrc } = load("rss.js")
const { ctx: F, src: feedsSrc } = load("feeds.js")
const fixture = f => fs.readFileSync(path.join(__dirname, "fixtures", f), "utf8")

let failed = 0
function check(name, ok) {
    console.log((ok ? "ok   - " : "FAIL - ") + name)
    if (!ok) failed = 1
}

const main = R.parse(fixture("uutiset/v1/majorHeadlines/YLE_UUTISET.rss"))
const [a, b, c, d] = main.items
check("channel title", main.title === "Yle Uutiset | Pääuutiset")
check("four items, channel <link> not taken as an item", main.items.length === 4)
check("CDATA title with quotes and dash",
    a.title === "Hallitus esittää muutoksia työttömyysturvaan – \"Tämä koskee kaikkia\"")
check("link", a.link === "https://yle.fi/a/74-20100001")
check("summary strips HTML", a.summary === "Esitys lähtee lausuntokierrokselle ensi viikolla.")
check("image from <enclosure>", a.image === "https://images.cdn.yle.fi/image/upload/w_800/39-100001.jpg")
check("categories", a.categories.join() === "Kotimaa,Politiikka")
check("guid as id", a.id === "74-20100001")
check("+0300 date", a.date === Date.UTC(2026, 8, 30, 9, 3, 15))

check("numeric entities and &amp; in title", b.title === "Sää kylmenee viikonloppuna & lunta tulee pohjoiseen")
check("escaped HTML in description", b.summary === "Pakkasta voi olla jopa –15 astetta.")
check("image from <media:content>", b.image === "https://images.cdn.yle.fi/image/upload/w_800/39-100002.jpg")
check("GMT date", b.date === Date.UTC(2026, 8, 30, 8, 30, 0))

check("image from <img> in description", c.image === "https://images.cdn.yle.fi/image/upload/w_400/39-100003.jpg")
check("summary without the image", c.summary === "Erityisesti nuorten liikunta on vähentynyt.")

check("audio enclosure is not an image", d.image === "")
check("missing description is empty", d.summary === "")
check("missing guid falls back to link", d.id === "https://yle.fi/a/74-20100004")

const recent = R.parse(fixture("uutiset/v1/recent.rss"))
check("recent feed parses", recent.items.length === 2)
check("image from <media:thumbnail>", recent.items[0].image === "https://images.cdn.yle.fi/image/upload/w_300/39-100010.jpg")
check("item without image or category", recent.items[1].image === "" && recent.items[1].categories.length === 0)

let threw = ""
try { R.parse("<html><body>Error 503</body></html>") } catch (e) { threw = e.message }
check("HTML error page is rejected", threw === "Not an RSS feed")
check("empty channel is fine", R.parse("<rss><channel><title>x</title></channel></rss>").items.length === 0)

check("ISO date", R.parseDate("2026-09-30T12:00:00+03:00") === Date.UTC(2026, 8, 30, 9, 0, 0))
check("ISO Z date", R.parseDate("2026-09-30T09:00:00Z") === Date.UTC(2026, 8, 30, 9, 0, 0))
check("date without weekday", R.parseDate("30 Sep 2026 12:00:00 +0300") === Date.UTC(2026, 8, 30, 9, 0, 0))
check("EEST zone", R.parseDate("Tue, 30 Sep 2026 12:00 EEST") === Date.UTC(2026, 8, 30, 9, 0, 0))
check("garbage date is NaN", isNaN(R.parseDate("soon")))

const now = Date.UTC(2026, 8, 30, 10, 0, 0)
check("just now", R.relativeTime(now - 20000, now) === "just now")
check("minutes", R.relativeTime(now - 5 * 60000, now) === "5 min ago")
check("hours", R.relativeTime(now - 3 * 3600000, now) === "3 h ago")
check("no date, no text", R.relativeTime(NaN, now) === "")
check("older dates get a date", /^\d{1,2}\.\d{1,2}\.2026 \d{1,2}:\d{2}$/.test(R.relativeTime(now - 5 * 86400000, now)))

// The sources and their feeds.
check("three sources: Yle, MTV Uutiset, AP News", F.sources.map(x => x.key).join() === "yle,mtv,ap")
check("Yle's front page", F.url(F.byKey("yle/main")) === "https://feeds.yle.fi/uutiset/v1/majorHeadlines/YLE_UUTISET.rss")
check("Yle's kotimaa topic id", F.url(F.byKey("yle/kotimaa")).endsWith("publisherIds=YLE_UUTISET&concepts=18-34837"))
check("Yle's sports from Yle Urheilu", F.url(F.byKey("yle/urheilu")).endsWith("publisherIds=YLE_URHEILU"))
check("MTV's latest news", F.url(F.byKey("mtv/main")) === "https://www.mtvuutiset.fi/api/feed/rss/uutiset_uusimmat")
check("AP's top stories from AP's Flipboard", F.url(F.byKey("ap/top")) === "https://flipboard.com/@associatedpress/top-stories-u7govdf1z.rss")
check("category counts", F.source("yle").categories.length === 13 && F.source("mtv").categories.length === 2
      && F.source("ap").categories.length === 10)
check("every key starts with its source's", F.sources.every(src => src.categories.every(c => c.key.indexOf(src.key + "/") === 0)))
const keys = [].concat(...F.sources.map(src => src.categories.map(c => c.key)))
check("category keys unique across sources", new Set(keys).size === keys.length)
check("source of a key", F.source("ap/sports").key === "ap" && F.source("mtv/all").name === "MTV Uutiset")
check("unknown key: its source's first category", F.byKey("ap/nope").key === "ap/top")
check("unknown source: Yle's front page", F.byKey("nope").key === "yle/main" && F.source("").key === "yle")
check("old single-app keys fall back safely", F.byKey("main").key === "yle/main" && F.byKey("kotimaa").key === "yle/main")
check("base can be overridden, keeping the feed's path",
      F.url(F.byKey("ap/top"), "http://127.0.0.1:1/") === "http://127.0.0.1:1/@associatedpress/top-stories-u7govdf1z.rss"
      && F.url(F.byKey("yle/latest"), "http://127.0.0.1:1/") === "http://127.0.0.1:1/uutiset/v1/recent.rss?publisherIds=YLE_UUTISET")
check("every source has its colour, site and home page",
      F.sources.every(src => /^#[0-9a-f]{6}$/.test(src.color) && src.site && /^https:\/\//.test(src.home)))

// AP's feed (example) parses too.
const apFeed = R.parse(fixture("@associatedpress/top-stories-u7govdf1z.rss"))
check("AP feed: three stories linking to apnews.com",
      apFeed.items.length === 3 && apFeed.items.every(i => i.link.indexOf("https://apnews.com/") === 0))
check("AP feed: photo from <media:content>", apFeed.items[0].image === "https://kuvat.example/ap/1.jpg")

check("ES5 only (no let/const/arrow/template)",
    ![rssSrc, feedsSrc].some(s => /\b(let|const)\s|=>|`/.test(s)))

process.exit(failed)
