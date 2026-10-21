// Reads a news story out of its web page: the headline, lead, time, the
// photos with their captions, and the text, in order.
//
// Plain ES5 with no .pragma or imports, so the same file works three ways:
// in Sailfish's Qt 5.6 JavaScript engine, inside a WorkerScript (through
// Qt.include, so a big page never stalls the screen), and in Node for the
// tests.
//
// It doesn't rely on any one site's layout. It reads the page's own
// article markup (<article>, or failing that <main>): paragraphs,
// subheadings, quotes, list items and <figure>s with their photos and
// captions. When that gives too little, the text comes from the article
// data most news pages embed for search engines (application/ld+json), or
// from the data a page built with JavaScript carries (Next.js and the like).
// The headline, lead, main photo and time come from the page's meta tags
// or that same data.

var ARTICLE_ENTITIES = { amp: "&", lt: "<", gt: ">", quot: "\"", apos: "'", nbsp: "\u00a0",
                         auml: "\u00e4", ouml: "\u00f6", aring: "\u00e5",
                         Auml: "\u00c4", Ouml: "\u00d6", Aring: "\u00c5",
                         eacute: "\u00e9", ndash: "\u2013", mdash: "\u2014",
                         hellip: "\u2026", rsquo: "\u2019", lsquo: "\u2018",
                         rdquo: "\u201d", ldquo: "\u201c", shy: "", laquo: "\u00ab", raquo: "\u00bb" }

function articleDecode(s) {
    return String(s).replace(/&(#x[0-9a-fA-F]+|#[0-9]+|[a-zA-Z]+);/g, function(m, e) {
        if (e.charAt(0) === "#") {
            var code = e.charAt(1) === "x" || e.charAt(1) === "X"
                    ? parseInt(e.substring(2), 16) : parseInt(e.substring(1), 10)
            return isNaN(code) ? m : String.fromCharCode(code)
        }
        return ARTICLE_ENTITIES.hasOwnProperty(e) ? ARTICLE_ENTITIES[e] : m
    })
}

// HTML to one tidy line (or lines, for <br>) of plain text.
function articleText(html) {
    return articleDecode(String(html || "")
                         .replace(/<br\s*\/?>/gi, "\n")
                         .replace(/<[^>]*>/g, ""))
        .replace(/[ \t\r\u00a0]+/g, " ")
        .replace(/ *\n */g, "\n")
        .replace(/\n{2,}/g, "\n")
        .trim()
}

function articleAttr(tag, name) {
    var m = new RegExp("\\s" + name + "\\s*=\\s*(\"([^\"]*)\"|'([^']*)'|([^\\s>]+))", "i").exec(tag)
    if (!m) return ""
    return articleDecode(m[2] !== undefined ? m[2] : m[3] !== undefined ? m[3] : m[4])
}

// An address as the phone can load it: relative and scheme-less ones are
// made absolute against the page's address.
function articleAbsolute(url, pageUrl) {
    url = String(url || "").trim()
    if (url === "" || /^data:/i.test(url)) return ""
    if (/^https?:\/\//i.test(url)) return url
    var origin = /^(https?:)\/\/[^\/]+/i.exec(pageUrl || "")
    if (url.indexOf("//") === 0) return (origin ? origin[1] : "https:") + url
    if (!origin) return url
    if (url.charAt(0) === "/") return origin[0] + url
    return String(pageUrl).replace(/[^\/]*$/, "") + url
}

// From a srcset ("a.jpg 320w, b.jpg 1080w"), the picture nearest to a
// phone's width without being smaller, else the biggest there is.
function articlePickSrcset(srcset) {
    var best = "", bestW = -1, fit = "", fitW = 1e9
    var parts = String(srcset || "").split(/,\s+/)
    for (var i = 0; i < parts.length; i++) {
        var bits = parts[i].trim().split(/\s+/)
        if (!bits[0]) continue
        var w = bits[1] && /w$/.test(bits[1]) ? parseInt(bits[1], 10) : 0
        if (w > bestW) { best = bits[0]; bestW = w }
        if (w >= 1000 && w < fitW) { fit = bits[0]; fitW = w }
    }
    return fit || best
}

// The picture of an <img>, <source> or <figure>'s markup.
function articleImageOf(html, pageUrl) {
    var tags = String(html).match(/<(img|source)\s[^>]*>/gi) || []
    for (var i = 0; i < tags.length; i++) {
        var t = tags[i]
        var candidates = [articlePickSrcset(articleAttr(t, "srcset")),
                          articlePickSrcset(articleAttr(t, "data-srcset")),
                          articleAttr(t, "data-src"), articleAttr(t, "src")]
        for (var c = 0; c < candidates.length; c++) {
            var url = articleAbsolute(candidates[c], pageUrl)
            if (url && !/\.svg(\?|$)/i.test(url) && !/^data:/i.test(url)) return url
        }
    }
    return ""
}

function articleMeta(html, key) {
    var re = new RegExp("<meta\\s[^>]*(?:property|name)\\s*=\\s*[\"']" + key + "[\"'][^>]*>", "i")
    var tag = re.exec(html)
    return tag ? articleAttr(tag[0], "content") : ""
}

// The article data pages embed for search engines, if there is any.
function articleJsonLd(html) {
    var re = /<script[^>]*type\s*=\s*["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi
    var m, found = null
    function look(node) {
        if (!node || typeof node !== "object" || found) return
        if (node instanceof Array) {
            for (var i = 0; i < node.length; i++) look(node[i])
            return
        }
        var type = String(node["@type"] || "")
        if (/(News)?Article|Report|BlogPosting/.test(type) && (node.headline || node.articleBody)) {
            found = node
            return
        }
        if (node["@graph"]) look(node["@graph"])
        if (node.mainEntity) look(node.mainEntity)
    }
    while ((m = re.exec(html)) !== null && !found) {
        try { look(JSON.parse(m[1])) } catch (e) { }
    }
    return found
}

function articleLdImage(image) {
    if (!image) return ""
    if (typeof image === "string") return image
    if (image instanceof Array) return articleLdImage(image[0])
    return image.url || image.contentUrl || ""
}

// ISO time to epoch ms, or NaN (Qt 5.6's Date.parse can't be trusted).
function articleTime(s) {
    var m = /^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2})(?::(\d{2}))?(?:\.\d+)?(Z|[+-]\d{2}:?\d{2})?/.exec(String(s || ""))
    if (!m) return NaN
    var t = Date.UTC(+m[1], +m[2] - 1, +m[3], +m[4], +m[5], m[6] ? +m[6] : 0)
    var z = m[7] || "Z"
    if (z !== "Z") {
        var zs = z.replace(":", "")
        t -= (zs.charAt(0) === "-" ? -1 : 1) * (+zs.substr(1, 2) * 60 + +zs.substr(3, 2)) * 60000
    }
    return t
}

// The inside of every <tag> element, nesting counted, so a story with
// "read also" <article>s inside it isn't cut off at the first of them.
function articleElements(html, tag) {
    var re = new RegExp("<(\\/?)" + tag + "(\\s[^>]*)?>", "gi")
    var open = [], out = [], m
    while ((m = re.exec(html)) !== null) {
        if (!m[1]) open.push(re.lastIndex)
        else if (open.length > 0) out.push(html.substring(open.pop(), m.index))
    }
    return out
}

// The parts of the page that may hold the story, most likely first: each
// <article>, then <main>, then the whole <body>.
function articleRegions(html) {
    var regions = { articles: articleElements(html, "article"), main: "", body: "" }
    var m = articleElements(html, "main")
    if (m.length > 0) regions.main = m[0]
    m = /<body(\s[^>]*)?>([\s\S]*)<\/body\s*>/i.exec(html)
    regions.body = m ? m[2] : html
    return regions
}

// How much story there is in blocks: all the text, and how many
// paragraphs are long enough to be real ones.
function articleScore(blocks) {
    var chars = 0, paragraphs = 0
    for (var i = 0; i < blocks.length; i++) {
        if (blocks[i].type === "image") continue
        chars += blocks[i].text.length
        if (blocks[i].type === "text" && blocks[i].text.length >= 40) paragraphs++
    }
    return { chars: chars, paragraphs: paragraphs }
}

function articleWeak(score) {
    return score.paragraphs < 2 || score.chars < 400
}

// The story from the page's markup: the fullest <article> (with the ones
// nested in it, usually links to other stories, left out), or <main> or
// the <body> when no <article> has much.
function articleFromMarkup(html, pageUrl) {
    var regions = articleRegions(html)
    var best = [], bestScore = { chars: -1, paragraphs: 0 }
    function consider(region) {
        region = region.replace(/<article(\s[^>]*)?>[\s\S]*?<\/article\s*>/gi, "")
        var blocks = articleBlocks(articleClean(region), pageUrl)
        var score = articleScore(blocks)
        if (score.chars > bestScore.chars) { best = blocks; bestScore = score }
    }
    for (var i = 0; i < regions.articles.length; i++) consider(regions.articles[i])
    if (articleWeak(bestScore) && regions.main) consider(regions.main)
    if (articleWeak(bestScore)) consider(regions.body)
    return best
}

// Plain text with blank lines (or line breaks) between paragraphs.
function articleTextParts(text) {
    var blocks = []
    var parts = String(text).split(/\n\s*\n|\r?\n/)
    for (var i = 0; i < parts.length; i++) {
        var t = articleText(parts[i])
        if (t) blocks.push({ type: "text", text: t })
    }
    return blocks
}

// The data many sites build their pages from with JavaScript, embedded in
// the page: <script type="application/json"> (Next.js's __NEXT_DATA__
// among them) and "window.__STATE__ = {...}" assignments.
function articleScripts(html) {
    var re = /<script([^>]*)>([\s\S]*?)<\/script\s*>/gi
    var roots = [], m
    while ((m = re.exec(html)) !== null) {
        var attrs = m[1], body = m[2].trim()
        if (body.length < 200 || /ld\+json/i.test(attrs)) continue
        var json = ""
        if (/application\/json/i.test(attrs)) {
            json = body
        } else {
            var a = /^(?:window\.|self\.|var\s+|let\s+|const\s+)?[\w$.]+(?:\[["'][^"']+["']\])?\s*=\s*([\[{][\s\S]*[\]}])\s*;?\s*$/.exec(body)
            if (a) json = a[1]
            var q = /JSON\.parse\(\s*("(?:[^"\\]|\\.)*")\s*\)/.exec(body)
            if (!json && q) {
                try { json = JSON.parse(q[1]) } catch (e) { }
            }
        }
        if (!json) continue
        try { roots.push(JSON.parse(json)) } catch (e) { }
    }
    return roots
}

// The text of a block in the data: its own string, or its text, html or
// content, or its pieces (the spans of a paragraph) put together.
function articleDataRaw(node, depth) {
    if (depth > 6 || node === null || node === undefined) return ""
    if (typeof node === "string") return node
    if (typeof node !== "object") return ""
    if (node instanceof Array) {
        var parts = []
        for (var i = 0; i < node.length; i++) parts.push(articleDataRaw(node[i], depth + 1))
        return parts.join("")
    }
    var keys = ["text", "html", "content", "value", "body", "children", "nodes", "spans"]
    for (var k = 0; k < keys.length; k++) {
        if (!node.hasOwnProperty(keys[k])) continue
        var r = articleDataRaw(node[keys[k]], depth + 1)
        if (r) return r
    }
    return ""
}

// A picture's address somewhere in a block of the data.
function articleDataImage(node, pageUrl, depth) {
    depth = depth || 0
    if (depth > 4 || !node || typeof node !== "object") return ""
    for (var k in node) {
        if (!node.hasOwnProperty(k)) continue
        var v = node[k]
        if (typeof v === "string") {
            if (/^(https?:)?\/\/|^\//i.test(v)
                    && /\.(jpe?g|png|webp|avif)(\?|$)|\/(image|images|img|kuva|kuvat)\//i.test(v))
                return articleAbsolute(v, pageUrl)
        } else if (typeof v === "object") {
            var found = articleDataImage(v, pageUrl, depth + 1)
            if (found) return found
        }
    }
    return ""
}

function articleDataCaption(node) {
    var places = [node, node.image, node.media, node.data, node.picture]
    var keys = ["caption", "alt", "description", "text"]
    for (var p = 0; p < places.length; p++) {
        var place = places[p]
        if (!place || typeof place !== "object") continue
        for (var k = 0; k < keys.length; k++) {
            var v = place[keys[k]]
            if (typeof v === "string" && v.length < 500) return articleText(v)
        }
    }
    return ""
}

// A list in the data read as a story: each item a paragraph, subheading,
// quote, list item or picture, by its own type where it says one.
function articleDataList(list, pageUrl) {
    var out = []
    for (var i = 0; i < list.length; i++) {
        var el = list[i]
        if (typeof el === "string") {
            if (/<(p|h[2-4]|blockquote|li|figure)[\s>]/i.test(el)) out = out.concat(articleBlocks(articleClean(el), pageUrl))
            else if (el.length >= 40) out.push({ type: "text", text: articleText(el) })
            continue
        }
        if (!el || typeof el !== "object" || el instanceof Array) continue
        var kind = String(el.type || el._type || el.__typename || el.blockType || el.kind || "").toLowerCase()
        var raw = articleDataRaw(el, 0)
        if (/image|picture|photo|kuva|gallery/.test(kind) || !raw) {
            var src = articleDataImage(el, pageUrl)
            if (src) out.push({ type: "image", src: src, caption: articleDataCaption(el) })
            continue
        }
        if (/<(p|h[2-4]|blockquote|li)[\s>]/i.test(raw)) {
            out = out.concat(articleBlocks(articleClean(raw), pageUrl))
            continue
        }
        var t = articleText(raw)
        if (t.length < 2) continue
        var type = /head|title|^h[2-4]$/.test(kind) ? "heading"
                 : /quote/.test(kind) ? "quote"
                 : /list|item|bullet/.test(kind) ? "item" : "text"
        out.push({ type: type, text: t })
    }
    return out
}

// The fullest story anywhere in the page's embedded data, or null.
function articleFromData(html, pageUrl) {
    var roots = articleScripts(html)
    var best = null, bestChars = 0, visited = 0
    function consider(blocks) {
        var score = articleScore(blocks)
        if (score.paragraphs >= 2 && score.chars > bestChars) { best = blocks; bestChars = score.chars }
    }
    function walk(node, depth) {
        if (++visited > 300000 || depth > 60 || node === null || node === undefined) return
        if (typeof node === "string") {
            if (node.length < 200) return
            if (/<p[\s>]/i.test(node)) consider(articleBlocks(articleClean(node), pageUrl))
            else if (/\n/.test(node)) consider(articleTextParts(node))
            return
        }
        if (typeof node !== "object") return
        if (node instanceof Array) {
            if (node.length >= 2) consider(articleDataList(node, pageUrl))
            for (var i = 0; i < node.length; i++) walk(node[i], depth + 1)
            return
        }
        for (var k in node) if (node.hasOwnProperty(k)) walk(node[k], depth + 1)
    }
    for (var r = 0; r < roots.length; r++) walk(roots[r], 0)
    return best
}

// Takes out what isn't the story: scripts, styles, navigation, share bars,
// forms, related links.
function articleClean(html) {
    var drop = ["script", "style", "noscript", "svg", "nav", "aside", "footer", "form", "button", "iframe", "template"]
    var s = String(html).replace(/<!--[\s\S]*?-->/g, "")
    for (var i = 0; i < drop.length; i++)
        s = s.replace(new RegExp("<" + drop[i] + "(\\s[^>]*)?>[\\s\\S]*?<\\/" + drop[i] + "\\s*>", "gi"), "")
    return s
}

// The story, in order: [{ type: "text" | "heading" | "quote" | "item",
// text } or { type: "image", src, caption }].
function articleBlocks(region, pageUrl) {
    var blocks = []
    var re = /<(p|h2|h3|h4|blockquote|li|figure)(\s[^>]*)?>([\s\S]*?)<\/\1\s*>|<img\s[^>]*>|<picture(\s[^>]*)?>[\s\S]*?<\/picture\s*>/gi
    var m
    while ((m = re.exec(region)) !== null) {
        var tag = (m[1] || "").toLowerCase()
        if (tag === "figure" || tag === "") {
            var src = articleImageOf(m[0], pageUrl)
            if (!src) {
                // A figure that's a quote or a chart without a picture.
                var t = articleText(m[3] || "")
                if (tag === "figure" && t) blocks.push({ type: "quote", text: t })
                continue
            }
            var cap = /<figcaption(\s[^>]*)?>([\s\S]*?)<\/figcaption\s*>/i.exec(m[0])
            var caption = cap ? articleText(cap[2]) : articleAttr(/<img\s[^>]*>/i.exec(m[0]) ? /<img\s[^>]*>/i.exec(m[0])[0] : "", "alt")
            blocks.push({ type: "image", src: src, caption: caption })
            continue
        }
        var text = articleText(m[3])
        if (text.length < 2) continue
        // A heading that's only a link is a link to another story.
        if (/^h/.test(tag) && /^\s*<a\s[^>]*>[\s\S]*<\/a>\s*$/i.test(m[3])) continue
        if (tag === "p") blocks.push({ type: "text", text: text })
        else if (tag === "blockquote") blocks.push({ type: "quote", text: text })
        else if (tag === "li") blocks.push({ type: "item", text: text })
        else blocks.push({ type: "heading", text: text })
    }
    return blocks
}

// { title, lead, published (ms or NaN), image, blocks, source }
// source says where the text came from: "page", "data" or "none".
function parseArticle(html, pageUrl) {
    html = String(html || "")
    var ld = articleJsonLd(html)

    var h1 = /<h1(\s[^>]*)?>([\s\S]*?)<\/h1\s*>/i.exec(html)
    var title = articleMeta(html, "og:title") || (ld && ld.headline) || (h1 ? articleText(h1[2]) : "")
    var lead = articleMeta(html, "og:description") || articleMeta(html, "description") || (ld && ld.description) || ""
    var image = articleAbsolute(articleMeta(html, "og:image") || articleLdImage(ld && ld.image), pageUrl)
    var published = articleTime(articleMeta(html, "article:published_time") || (ld && ld.datePublished) || "")

    var blocks = articleFromMarkup(html, pageUrl)
    var markup = articleScore(blocks)
    var source = "page"
    if (articleWeak(markup)) {
        // Little in the markup: the story from the article data for search
        // engines, or the data the page is built from, whichever has more.
        var alt = ld && ld.articleBody ? articleTextParts(ld.articleBody) : null
        var built = articleFromData(html, pageUrl)
        if (built && (!alt || articleScore(built).chars > articleScore(alt).chars)) alt = built
        if (alt && articleScore(alt).chars > markup.chars) {
            var hasPicture = false
            for (var a = 0; a < alt.length; a++) if (alt[a].type === "image") hasPicture = true
            if (!hasPicture) {
                // Keep whatever pictures the markup did have.
                var pictures = []
                for (var p = 0; p < blocks.length; p++) if (blocks[p].type === "image") pictures.push(blocks[p])
                alt = pictures.concat(alt)
            }
            blocks = alt
            source = "data"
        }
    }
    if (source === "page" && markup.chars === 0) source = "none"

    // Not the headline or lead a second time, nor the same photo twice.
    var out = [], seen = {}
    title = articleText(title)
    lead = articleText(lead)
    for (var b = 0; b < blocks.length; b++) {
        var blk = blocks[b]
        if (blk.type === "image") {
            if (seen[blk.src]) continue
            seen[blk.src] = true
        } else if (blk.text === title || blk.text === lead) {
            continue
        }
        out.push(blk)
    }
    // A story doesn't end on a subheading: one there heads something else.
    while (out.length > 0 && out[out.length - 1].type === "heading") out.pop()
    // The main photo goes first, unless the story already starts with one.
    if (image && !seen[image] && !(out.length > 0 && out[0].type === "image"))
        out.unshift({ type: "image", src: image, caption: "" })

    return { title: title, lead: lead, published: published, image: image, blocks: out, source: source }
}

// A short report on how a page is built, for when its story can't be found:
// what the app got, which tags and embedded data it has, where long texts
// sit in that data, and the markup around the lead. Texts are cut short.
function articleReport(html, pageUrl, status) {
    html = String(html || "")
    var lines = ["UutisFish page report", "address: " + pageUrl, "status: " + status + ", " + html.length + " characters"]
    function count(tag) {
        var m = html.match(new RegExp("<" + tag + "[\\s>]", "gi"))
        return tag + " " + (m ? m.length : 0)
    }
    lines.push("title: " + articleMeta(html, "og:title"))
    lines.push("tags: " + ["article", "main", "section", "p", "h2", "figure", "img", "div", "span", "script"].map(count).join(", "))

    var re = /<script([^>]*)>([\s\S]*?)<\/script\s*>/gi, m, scripts = []
    while ((m = re.exec(html)) !== null) {
        if (m[2].length < 500) continue
        var id = articleAttr(m[0].substring(0, m[0].indexOf(">") + 1), "id")
        var type = articleAttr(m[0].substring(0, m[0].indexOf(">") + 1), "type")
        scripts.push((id || "-") + " " + (type || "js") + " " + Math.round(m[2].length / 1024) + " kB: "
                     + m[2].trim().substring(0, 50).replace(/\s+/g, " "))
    }
    lines.push("big scripts: " + scripts.length)
    for (var s = 0; s < scripts.length && s < 12; s++) lines.push("  " + scripts[s])

    var ld = articleJsonLd(html)
    lines.push("ld+json article: " + (ld ? String(ld["@type"]) + ", articleBody " + (ld.articleBody ? String(ld.articleBody).length : "none") : "none"))

    // Where the long texts and lists are in the embedded data.
    var roots = articleScripts(html), found = [], seen = 0
    function walk(node, path, depth) {
        if (found.length >= 25 || ++seen > 200000 || depth > 40 || node === null || node === undefined) return
        if (typeof node === "string") {
            if (node.length >= 120) found.push(path + " (" + node.length + "): " + node.substring(0, 50).replace(/\s+/g, " "))
            return
        }
        if (typeof node !== "object") return
        if (node instanceof Array) {
            if (node.length >= 3 && node[0] && typeof node[0] === "object") {
                var kinds = []
                for (var i = 0; i < node.length && kinds.length < 6; i++) {
                    var el = node[i] || {}
                    kinds.push(String(el.type || el._type || el.__typename || Object.keys(el).slice(0, 3).join("/")))
                }
                found.push(path + "[" + node.length + "]: " + kinds.join(", "))
            }
            for (var j = 0; j < node.length; j++) walk(node[j], path + "[" + j + "]", depth + 1)
            return
        }
        for (var k in node) if (node.hasOwnProperty(k)) walk(node[k], path + "." + k, depth + 1)
    }
    for (var r = 0; r < roots.length; r++) walk(roots[r], "data" + r, 0)
    lines.push("embedded data: " + roots.length + (found.length ? ", long texts and lists:" : ""))
    for (var f = 0; f < found.length; f++) lines.push("  " + found[f])

    // The markup from the lead on, tags kept, texts cut to a few words.
    var lead = articleMeta(html, "og:description")
    var bodyStart = html.search(/<body[\s>]/i)
    var at = html.search(/<h1[\s>]/i)
    if (at < 0 && lead) at = html.indexOf(lead.substring(0, 25), bodyStart)
    if (at >= 0) {
        var piece = articleClean(html.substring(Math.max(0, at - 300), at + 6000))
            .replace(/>([^<]{30})[^<]+</g, ">$1…<")
            .replace(/\s+/g, " ")
        lines.push("markup from the lead on:", piece.substring(0, 2500))
    } else {
        lines.push("lead not found in the markup")
    }
    return lines.join("\n")
}
