// Unit tests for qml/js/article.js. Run: node tests/test_article.js
//
// The pages here are examples written for these tests in the usual shapes
// of news pages (article markup, lazy pictures, embedded article data).
// They are not copies of any site's pages: they check that the reader handles
// each shape, not what any one site serves.
const fs = require("fs")
const path = require("path")
const vm = require("vm")

const ctx = {}
vm.createContext(ctx)
vm.runInContext(fs.readFileSync(path.join(__dirname, "../qml/js/article.js"), "utf8"), ctx)
const parse = (html, url) => ctx.parseArticle(html, url || "https://news.example/a/1")

let failed = 0
function check(name, ok) {
    console.log((ok ? "ok   - " : "FAIL - ") + name)
    if (!ok) failed = 1
}
const types = a => a.blocks.map(b => b.type).join(",")

// 1. A page whose markup has the whole story.
const page = `<!doctype html><html><head>
<meta property="og:title" content="Hallitus esittää muutoksia &ndash; &quot;Tämä koskee kaikkia&quot;">
<meta property="og:description" content="Esitys lähtee lausuntokierrokselle ensi viikolla.">
<meta property="og:image" content="https://img.example/main-1200.jpg">
<meta property="article:published_time" content="2026-10-21T09:03:15+03:00">
<script>var tracking = "<p>not text</p>";</script>
<style>p { color: red }</style>
</head><body>
<nav><p>Etusivu</p><p>Uutiset</p></nav>
<article class="story">
  <header><h1>Hallitus esittää muutoksia</h1>
  <p class="lead">Esitys lähtee lausuntokierrokselle ensi viikolla.</p></header>
  <figure><picture><source srcset="https://img.example/a-320.jpg 320w, https://img.example/a-1080.jpg 1080w, https://img.example/a-2000.jpg 2000w">
  <img src="https://img.example/a-320.jpg" alt="Ministeri puhuu"></picture>
  <figcaption>Ministeri <b>puhui</b> eduskunnassa. Kuva: Kuvaaja</figcaption></figure>
  <p>Ensimmäinen kappale, jossa on <a href="/x">linkki</a> ja&nbsp;välilyönti.</p>
  <aside><p>Lue myös: jotain muuta</p></aside>
  <h2>Väliotsikko</h2>
  <p>Toinen kappale.<br>Rivinvaihdolla.</p>
  <blockquote><p>Lainaus joltakulta.</p></blockquote>
  <ul><li>Ensimmäinen kohta</li><li>Toinen kohta</li></ul>
  <figure><img data-src="/images/b.jpg" src="data:image/gif;base64,R0lGOD" alt="Kartta"></figure>
  <div class="share"><button>Jaa</button></div>
  <p>Viimeinen kappale.</p>
</article>
<footer><p>© Joku</p></footer>
</body></html>`

const a = parse(page, "https://news.example/a/74-1")
check("headline from the page's meta, entities decoded", a.title === 'Hallitus esittää muutoksia – "Tämä koskee kaikkia"')
check("lead", a.lead === "Esitys lähtee lausuntokierrokselle ensi viikolla.")
check("published time with its zone", a.published === Date.UTC(2026, 9, 21, 6, 3, 15))
check("the text came from the page", a.source === "page")
check("blocks in reading order", types(a) === "image,text,heading,text,quote,item,item,image,text")
check("the story starts with its own photo, so the preview photo isn't added too",
      !a.blocks.some(b => b.src === "https://img.example/main-1200.jpg"))
check("figure photo: the 1080 px one from the srcset", a.blocks[0].src === "https://img.example/a-1080.jpg")
check("caption from figcaption, tags removed", a.blocks[0].caption === "Ministeri puhui eduskunnassa. Kuva: Kuvaaja")
check("paragraph text: links unwrapped, nbsp a space", a.blocks[1].text === "Ensimmäinen kappale, jossa on linkki ja välilyönti.")
check("subheading", a.blocks[2].text === "Väliotsikko")
check("line break kept", a.blocks[3].text === "Toinen kappale.\nRivinvaihdolla.")
check("quote", a.blocks[4].text === "Lainaus joltakulta.")
check("list items", a.blocks[5].text === "Ensimmäinen kohta" && a.blocks[6].text === "Toinen kohta")
check("lazy picture: data-src, made absolute", a.blocks[7].src === "https://news.example/images/b.jpg")
check("caption falls back to alt text", a.blocks[7].caption === "Kartta")
check("lead isn't repeated as a paragraph", !a.blocks.some(b => b.text === a.lead))
const all = a.blocks.map(b => b.text || "").join(" ")
check("no navigation, related links, footer or script text",
      !/Etusivu|Lue myös|©|not text|Jaa|color/.test(all))

// 2. A page that builds its story with JavaScript: little markup, but the
// article data for search engines has the text.
const scripted = `<html><head>
<script type="application/ld+json">{"@context":"https://schema.org","@graph":[
 {"@type":"WebPage","name":"x"},
 {"@type":"NewsArticle","headline":"Sää kylmenee & lunta tulee",
  "description":"Pakkasta jopa –15 astetta.","datePublished":"2026-10-21T08:30:00Z",
  "image":[{"@type":"ImageObject","url":"https://img.example/snow.jpg"}],
  "articleBody":"Ensimmäinen kappale.\\n\\nToinen kappale.\\n\\nKolmas."}]}</script>
</head><body><div id="root"><figure><img src="https://img.example/inline.jpg"><figcaption>Lumi</figcaption></figure></div></body></html>`
const s = parse(scripted)
check("headline from the article data", s.title === "Sää kylmenee & lunta tulee")
check("time from the article data", s.published === Date.UTC(2026, 9, 21, 8, 30, 0))
check("the text came from the article data", s.source === "data")
check("its paragraphs after the markup's picture", types(s) === "image,text,text,text"
      && s.blocks[0].src === "https://img.example/inline.jpg" && s.blocks[3].text === "Kolmas.")

// 2b. When the markup has no picture, the main photo leads the story.
const bare = parse(scripted.replace(/<figure>[\s\S]*<\/figure>/, ""))
check("main photo first when the story has none of its own",
      types(bare) === "image,text,text,text" && bare.blocks[0].src === "https://img.example/snow.jpg")

// 3. Nothing usable at all: no text, but no crash either.
const empty = parse("<html><body><div>Lataa sovellus</div></body></html>")
check("an empty page says so", empty.source === "none" && empty.blocks.length === 0 && empty.title === "")
check("junk in the data is ignored", parse('<script type="application/ld+json">{not json</script><article><p>Yksi.</p><p>Kaksi.</p></article>').source === "page")

// 4. Addresses.
check("scheme-less address", ctx.articleAbsolute("//img.example/x.jpg", "https://a.example/") === "https://img.example/x.jpg")
check("relative to the page", ctx.articleAbsolute("x.jpg", "https://a.example/dir/page") === "https://a.example/dir/x.jpg")
check("srcset without widths: the first", ctx.articlePickSrcset("one.jpg, two.jpg") === "one.jpg")
check("srcset all small: the biggest", ctx.articlePickSrcset("s.jpg 200w, m.jpg 640w") === "m.jpg")

// 5. The Qt 5.6 engine is ES5 only.
const src = fs.readFileSync(path.join(__dirname, "../qml/js/article.js"), "utf8")
check("ES5 only (no let/const/arrow/template)", !/\b(let|const)\s|=>|`/.test(src))

process.exit(failed)
