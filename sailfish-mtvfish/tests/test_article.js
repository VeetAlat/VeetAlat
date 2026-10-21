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

// 6. "Read also" stories inside the story's own <article>: the story isn't
// cut off at the first of them, and they're left out.
const para = n => `Kappale ${n}, jossa on tarpeeksi tekstiä ollakseen oikea kappale uutisessa.`
const nested = parse(`<html><body><main><article class="story"><h1>Otsikko</h1>
<p>${para(1)}</p>
<article class="teaser"><h3>Lue myös</h3><p>Toinen juttu, jota ei kuulu näyttää tässä.</p></article>
<p>${para(2)}</p><h2>Väliotsikko</h2><p>${para(3)}</p>
<article class="teaser"><p>Vielä yksi muu juttu.</p></article>
<p>${para(4)}</p><p>${para(5)}</p><p>${para(6)}</p></article></main></body></html>`)
check("nested articles: the whole story", nested.source === "page"
      && types(nested) === "text,text,heading,text,text,text,text" && nested.blocks[6].text === para(6))
check("nested articles: their text is left out", !nested.blocks.some(b => /juttu/.test(b.text)))

// 7. A page built with JavaScript (Next.js): the markup has only a lead,
// the story is in __NEXT_DATA__ as typed blocks with spans and pictures.
const next = {
    props: { pageProps: {
        related: [{ title: "Muu juttu", lead: "Ei tätä", url: "/artikkeli/muu/1" },
                  { title: "Kolmas juttu", lead: "Eikä tätä", url: "/artikkeli/kolmas/2" }],
        article: { title: "Hallitus esittää", body: [
            { type: "paragraph", children: [{ text: "Ensimmäinen kappale " }, { text: "kahdessa osassa, ja tarpeeksi pitkä." }] },
            { type: "image", image: { url: "https://kuvat.example/w_1080/1.jpg", caption: "Kuvateksti" } },
            { type: "paragraph", text: para(2) },
            { type: "heading", text: "Mitä seuraavaksi?" },
            { type: "quote", text: "Tämä on lainaus." },
            { type: "paragraph", text: para(3) },
            { type: "ad", id: "mainos-1" },
            { type: "paragraph", text: para(4) }
        ] } } } }
const built = parse(`<html><head><meta property="og:title" content="Hallitus esittää">
<meta property="og:image" content="https://kuvat.example/w_1200/main.jpg"></head><body>
<div id="__next"><h1>Hallitus esittää</h1><p>Vain ingressi.</p></div>
<script id="__NEXT_DATA__" type="application/json">${JSON.stringify(next)}</script></body></html>`,
    "https://www.mtvuutiset.fi/artikkeli/x/1")
check("built page: the story comes from its data", built.source === "data")
check("built page: main photo, then the blocks in order, ads skipped",
      types(built) === "image,text,image,text,heading,quote,text,text"
      && built.blocks[0].src === "https://kuvat.example/w_1200/main.jpg")
check("built page: spans joined", built.blocks[1].text === "Ensimmäinen kappale kahdessa osassa, ja tarpeeksi pitkä.")
check("built page: picture and caption from the data",
      built.blocks[2].src === "https://kuvat.example/w_1080/1.jpg" && built.blocks[2].caption === "Kuvateksti")
check("built page: other stories' leads aren't taken", !built.blocks.some(b => /Ei tätä|Eikä/.test(b.text || "")))

// 8. The story as HTML in "window.__STATE__ = {...}".
const state = { story: { id: 5, bodyHtml: `<p>${para(1)}</p><h2>Väli</h2><p>${para(2)}</p><figure><img src="/kuvat/2.jpg"><figcaption>Kuva 2</figcaption></figure><p>${para(3)}</p>` } }
const st = parse(`<html><body><div id="app"></div><script>window.__STATE__ = ${JSON.stringify(state)};</script></body></html>`,
                 "https://www.mtvuutiset.fi/artikkeli/y/5")
check("state page: HTML in the data read as a story", st.source === "data"
      && types(st) === "text,heading,text,image,text" && st.blocks[3].src === "https://www.mtvuutiset.fi/kuvat/2.jpg")

// 9. Draft.js-style blocks with their own types.
const draft = { content: { blocks: [
    { key: "a", type: "unstyled", text: para(1) }, { key: "b", type: "header-two", text: "Otsikko kaksi" },
    { key: "c", type: "unstyled", text: para(2) }, { key: "d", type: "unordered-list-item", text: "Kohta" },
    { key: "e", type: "atomic", text: " " }, { key: "f", type: "unstyled", text: para(3) }, { key: "g", type: "blockquote", text: "Lainaus" }
], entityMap: {} } }
const dr = parse(`<body><script type="application/json">${JSON.stringify(draft)}</script></body>`)
check("draft blocks by type", dr.source === "data" && types(dr) === "text,heading,text,item,text,quote")

// 10. A full story in the markup wins over anything in the data.
const both = parse(`<body><article>${[1, 2, 3, 4, 5, 6, 7, 8].map(n => `<p>${para(n)}</p>`).join("")}</article>
<script type="application/json">${JSON.stringify(next)}</script></body>`)
check("full markup is used as is", both.source === "page" && both.blocks.length === 8)

// 11. Data that isn't a story, or isn't valid, doesn't break anything.
const junk = parse(`<body><p>Lataa sovellus</p><script type="application/json">${JSON.stringify({ menu: ["Etusivu", "Urheilu"], x: "y".repeat(300) })}</script><script>window.a = {broken</script></body>`)
check("no story anywhere: says so", junk.source !== "data" && !junk.blocks.some(b => /Etusivu/.test(b.text || "")))

// 12. The page report for fixing the reader.
const report = ctx.articleReport(`<html><head><meta property="og:description" content="Vain ingressi."></head><body><h1>Otsikko</h1><p>Vain ingressi.</p>
<script id="__NEXT_DATA__" type="application/json">${JSON.stringify(next)}</script></body></html>`, "https://www.mtvuutiset.fi/artikkeli/x/1", 200)
check("report: what the page has", /status: 200/.test(report) && /tags: article 0/.test(report) && /__NEXT_DATA__ application\/json/.test(report))
check("report: where the data's long texts and lists are", /data0\.props\.pageProps\.article\.body\[8\]: paragraph, image, paragraph/.test(report))
check("report: the markup from the headline on", /<h1>Otsikko<\/h1>/.test(report))

// 5. The Qt 5.6 engine is ES5 only.
const src = fs.readFileSync(path.join(__dirname, "../qml/js/article.js"), "utf8")
check("ES5 only (no let/const/arrow/template)", !/\b(let|const)\s|=>|`/.test(src))

process.exit(failed)
