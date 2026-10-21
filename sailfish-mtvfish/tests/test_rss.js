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

const main = R.parse(fixture("api/feed/rss/uutiset_uusimmat"))
const [a, b, c, d] = main.items
check("channel title", main.title === "MTV Uutiset | Uutiset")
check("four items, channel <link> not taken as an item", main.items.length === 4)
check("CDATA title with quotes and dash",
    a.title === "Hallitus esittää muutoksia työttömyysturvaan – \"Tämä koskee kaikkia\"")
check("link", a.link === "https://www.mtvuutiset.fi/artikkeli/hallitus-esittaa-muutoksia-tyottomyysturvaan/10000001")
check("summary strips HTML", a.summary === "Esitys lähtee lausuntokierrokselle ensi viikolla.")
check("image from <enclosure>", a.image === "https://kuvat.example/w_800/100001.jpg")
check("categories", a.categories.join() === "Kotimaa,Politiikka")
check("guid as id", a.id === "10000001")
check("+0300 date", a.date === Date.UTC(2026, 8, 30, 9, 3, 15))

check("numeric entities and &amp; in title", b.title === "Sää kylmenee viikonloppuna & lunta tulee pohjoiseen")
check("escaped HTML in description", b.summary === "Pakkasta voi olla jopa –15 astetta.")
check("image from <media:content>", b.image === "https://kuvat.example/w_800/100002.jpg")
check("GMT date", b.date === Date.UTC(2026, 8, 30, 8, 30, 0))

check("image from <img> in description", c.image === "https://kuvat.example/w_400/100003.jpg")
check("summary without the image", c.summary === "Erityisesti nuorten liikunta on vähentynyt.")

check("audio enclosure is not an image", d.image === "")
check("missing description is empty", d.summary === "")
check("missing guid falls back to link", d.id === "https://www.mtvuutiset.fi/artikkeli/esimerkki/10000004")

const recent = R.parse(fixture("mtvuutiset/api/feed/rss/mtv_uusimmat_20"))
check("recent feed parses", recent.items.length === 2)
check("image from <media:thumbnail>", recent.items[0].image === "https://kuvat.example/w_300/100010.jpg")
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

check("2 categories, news first", F.categories.length === 2 && F.categories[0].key === "main")
check("news is MTV's latest news feed",
    F.url(F.byKey("main")) === "https://www.mtvuutiset.fi/api/feed/rss/uutiset_uusimmat")
check("all of MTV's latest 20", F.url(F.byKey("all")) === "https://api.mtvuutiset.fi/mtvuutiset/api/feed/rss/mtv_uusimmat_20")
check("unknown key falls back to main", F.byKey("nope").key === "main")
check("base can be overridden, keeping the feed's path",
    F.url(F.byKey("all"), "http://127.0.0.1:1/") === "http://127.0.0.1:1/mtvuutiset/api/feed/rss/mtv_uusimmat_20")
const keys = F.categories.map(c => c.key)
check("category keys unique", new Set(keys).size === keys.length)

check("ES5 only (no let/const/arrow/template)",
    ![rssSrc, feedsSrc].some(s => /\b(let|const)\s|=>|`/.test(s)))

process.exit(failed)
