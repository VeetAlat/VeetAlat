.pragma library

// A small, forgiving RSS 2.0 parser, plus date and text helpers.
//
// Plain ES5 on purpose: Sailfish OS's QML engine (Qt 5.6) has no let,
// const, arrow functions or template strings, and its Date.parse can't
// read RSS dates, so those are parsed here too. Works in Node for tests.
//
// Article images are looked for in every usual place: <enclosure>,
// <media:content>, <media:thumbnail>, then an <img> in the description.

var MONTHS = { jan: 0, feb: 1, mar: 2, apr: 3, may: 4, jun: 5,
               jul: 6, aug: 7, sep: 8, oct: 9, nov: 10, dec: 11 }

var NAMED_ENTITIES = { amp: "&", lt: "<", gt: ">", quot: "\"", apos: "'", nbsp: "\u00a0",
                       auml: "\u00e4", ouml: "\u00f6", aring: "\u00e5",
                       Auml: "\u00c4", Ouml: "\u00d6", Aring: "\u00c5",
                       eacute: "\u00e9", ndash: "\u2013", mdash: "\u2014",
                       hellip: "\u2026", rsquo: "\u2019", lsquo: "\u2018",
                       rdquo: "\u201d", ldquo: "\u201c" }

function decodeEntities(s) {
    return s.replace(/&(#x[0-9a-fA-F]+|#[0-9]+|[a-zA-Z]+);/g, function(m, e) {
        if (e.charAt(0) === "#") {
            var code = e.charAt(1) === "x" || e.charAt(1) === "X"
                    ? parseInt(e.substring(2), 16) : parseInt(e.substring(1), 10)
            return isNaN(code) ? m : String.fromCharCode(code)
        }
        return NAMED_ENTITIES.hasOwnProperty(e) ? NAMED_ENTITIES[e] : m
    })
}

// Element text: CDATA unwrapped, entities decoded, trimmed.
function text(raw) {
    if (raw === null || raw === undefined) return ""
    var s = String(raw)
    var cdata = /^\s*<!\[CDATA\[([\s\S]*?)\]\]>\s*$/.exec(s)
    if (cdata) return cdata[1].trim()
    return decodeEntities(s.replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, "$1")).trim()
}

// HTML (e.g. a description) to plain text.
function stripTags(html) {
    return decodeEntities(String(html || "")
                          .replace(/<br\s*\/?>/gi, "\n")
                          .replace(/<\/p>/gi, "\n")
                          .replace(/<[^>]*>/g, ""))
        .replace(/[ \t\u00a0]+/g, " ")
        .replace(/\s*\n\s*/g, "\n")
        .trim()
}

function escapeRe(s) { return s.replace(/[.*+?^${}()|[\]\\:]/g, "\\$&") }

// Inner XML of the first <name>…</name> in xml, or null.
function element(xml, name) {
    var re = new RegExp("<" + escapeRe(name) + "(\\s[^>]*)?>([\\s\\S]*?)</" + escapeRe(name) + "\\s*>", "i")
    var m = re.exec(xml)
    return m ? m[2] : null
}

// Inner XML of every <name>…</name>.
function elements(xml, name) {
    var re = new RegExp("<" + escapeRe(name) + "(\\s[^>]*)?>([\\s\\S]*?)</" + escapeRe(name) + "\\s*>", "gi")
    var out = [], m
    while ((m = re.exec(xml)) !== null) out.push(m[2])
    return out
}

// Attribute of the first <name …> tag (self-closing or not), or "".
function attribute(xml, name, attr) {
    var tag = new RegExp("<" + escapeRe(name) + "\\s[^>]*>", "i").exec(xml)
    if (!tag) return ""
    var a = new RegExp("\\s" + escapeRe(attr) + "\\s*=\\s*(\"([^\"]*)\"|'([^']*)')", "i").exec(tag[0])
    return a ? decodeEntities(a[2] !== undefined ? a[2] : a[3]) : ""
}

function isImageEnclosure(xml) {
    var type = attribute(xml, "enclosure", "type")
    var url = attribute(xml, "enclosure", "url")
    return url !== "" && (type === "" || type.indexOf("image") === 0)
}

function imageOf(itemXml, descriptionHtml) {
    if (isImageEnclosure(itemXml)) return attribute(itemXml, "enclosure", "url")
    var media = attribute(itemXml, "media:content", "url")
    if (media) return media
    var thumb = attribute(itemXml, "media:thumbnail", "url")
    if (thumb) return thumb
    var img = /<img\s[^>]*src\s*=\s*["']([^"']+)["']/i.exec(descriptionHtml || "")
    return img ? decodeEntities(img[1]) : ""
}

// RFC 822 date ("Tue, 30 Sep 2026 12:03:15 +0300", "… GMT") to epoch ms,
// or NaN. ISO 8601 is accepted too.
function parseDate(s) {
    s = String(s || "").trim()
    var m = /^(?:[A-Za-z]{3},\s*)?(\d{1,2})\s+([A-Za-z]{3})[A-Za-z]*\s+(\d{2,4})\s+(\d{1,2}):(\d{2})(?::(\d{2}))?\s*([+-]\d{4}|[A-Za-z]{1,4})?$/.exec(s)
    if (m) {
        var month = MONTHS[m[2].toLowerCase()]
        if (month === undefined) return NaN
        var year = parseInt(m[3], 10)
        if (year < 100) year += 2000
        var utc = Date.UTC(year, month, parseInt(m[1], 10), parseInt(m[4], 10),
                           parseInt(m[5], 10), m[6] ? parseInt(m[6], 10) : 0)
        var zone = m[7] || "GMT"
        var offset = 0
        if (/^[+-]\d{4}$/.test(zone)) {
            var sign = zone.charAt(0) === "-" ? -1 : 1
            offset = sign * (parseInt(zone.substr(1, 2), 10) * 60 + parseInt(zone.substr(3, 2), 10))
        } else if (/^(EET)$/i.test(zone)) {
            offset = 120
        } else if (/^(EEST)$/i.test(zone)) {
            offset = 180
        }
        return utc - offset * 60000
    }
    var iso = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(?::(\d{2}))?(?:\.\d+)?(Z|[+-]\d{2}:?\d{2})?$/.exec(s)
    if (iso) {
        var t = Date.UTC(parseInt(iso[1], 10), parseInt(iso[2], 10) - 1, parseInt(iso[3], 10),
                         parseInt(iso[4], 10), parseInt(iso[5], 10), iso[6] ? parseInt(iso[6], 10) : 0)
        var z = iso[7] || "Z"
        if (z !== "Z") {
            var zs = z.replace(":", "")
            var sg = zs.charAt(0) === "-" ? -1 : 1
            t -= sg * (parseInt(zs.substr(1, 2), 10) * 60 + parseInt(zs.substr(3, 2), 10)) * 60000
        }
        return t
    }
    return NaN
}

// { title, items: [{ title, link, summary, date, image, categories, id }] }
// Throws Error("…") if the text isn't an RSS feed at all.
function parse(xml) {
    xml = String(xml || "")
    var channel = element(xml, "channel")
    if (channel === null) {
        throw new Error("Not an RSS feed")
    }
    var head = channel.split(/<item[\s>]/i)[0]
    var feed = { title: text(element(head, "title")), items: [] }

    var raw = elements(channel, "item")
    for (var i = 0; i < raw.length; i++) {
        var it = raw[i]
        var title = text(element(it, "title"))
        var link = text(element(it, "link"))
        if (!title && !link) continue
        var descHtml = text(element(it, "description"))
        var cats = elements(it, "category")
        var categories = []
        for (var c = 0; c < cats.length; c++) {
            var name = text(cats[c])
            if (name && categories.indexOf(name) < 0) categories.push(name)
        }
        feed.items.push({
            title: stripTags(title),
            link: link,
            summary: stripTags(descHtml),
            date: parseDate(text(element(it, "pubDate"))),
            image: imageOf(it, descHtml),
            categories: categories,
            id: text(element(it, "guid")) || link
        })
    }
    return feed
}

// "just now", "5 min ago", "3 h ago", "yesterday 14:05", "12.9.2026 14:05".
function relativeTime(ms, nowMs) {
    if (!isFinite(ms)) return ""
    var diff = Math.max(0, (nowMs - ms) / 60000)
    if (diff < 1) return "just now"
    if (diff < 60) return Math.floor(diff) + " min ago"
    if (diff < 12 * 60) return Math.floor(diff / 60) + " h ago"
    var d = new Date(ms), now = new Date(nowMs)
    function pad(n) { return (n < 10 ? "0" : "") + n }
    var clock = d.getHours() + ":" + pad(d.getMinutes())
    var yesterday = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 1)
    if (d.getFullYear() === now.getFullYear() && d.getMonth() === now.getMonth()
            && d.getDate() === now.getDate()) {
        return "today " + clock
    }
    if (d.getFullYear() === yesterday.getFullYear() && d.getMonth() === yesterday.getMonth()
            && d.getDate() === yesterday.getDate()) {
        return "yesterday " + clock
    }
    return d.getDate() + "." + (d.getMonth() + 1) + "." + d.getFullYear() + " " + clock
}
