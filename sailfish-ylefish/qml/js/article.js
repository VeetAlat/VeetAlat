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
// data most news pages embed for search engines (application/ld+json).
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

// The part of the page that holds the story: the longest <article>, or
// <main>, or the whole <body>.
function articleRegion(html) {
    var best = "", m
    var re = /<article(\s[^>]*)?>([\s\S]*?)<\/article\s*>/gi
    while ((m = re.exec(html)) !== null)
        if (m[2].length > best.length) best = m[2]
    if (best) return best
    m = /<main(\s[^>]*)?>([\s\S]*?)<\/main\s*>/i.exec(html)
    if (m) return m[2]
    m = /<body(\s[^>]*)?>([\s\S]*)<\/body\s*>/i.exec(html)
    return m ? m[2] : html
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

    var blocks = articleBlocks(articleClean(articleRegion(html)), pageUrl)
    var paragraphs = 0
    for (var i = 0; i < blocks.length; i++) if (blocks[i].type === "text") paragraphs++

    var source = "page"
    if (paragraphs < 2 && ld && ld.articleBody) {
        // Too little in the markup: the text from the embedded data, with
        // whatever pictures the markup did have.
        var pictures = []
        for (var p = 0; p < blocks.length; p++) if (blocks[p].type === "image") pictures.push(blocks[p])
        blocks = pictures
        var parts = String(ld.articleBody).split(/\n\s*\n|\r?\n/)
        for (var q = 0; q < parts.length; q++) {
            var t = articleText(parts[q])
            if (t) blocks.push({ type: "text", text: t })
        }
        source = "data"
    } else if (paragraphs === 0) {
        source = "none"
    }

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
    // The main photo goes first, unless the story already starts with one.
    if (image && !seen[image] && !(out.length > 0 && out[0].type === "image"))
        out.unshift({ type: "image", src: image, caption: "" })

    return { title: title, lead: lead, published: published, image: image, blocks: out, source: source }
}
