.pragma library

// MTV Uutiset's RSS feeds. MTV doesn't publish a feed list the build could
// reach, so these are the two feeds known from feed directories: the latest
// news, and the latest 20 stories from all of mtvuutiset.fi.
//
// base can be overridden (tests serve local fixtures): the feed's address
// is then fetched from there, minus its host.

var DEFAULT_BASE = ""

var categories = [
    { key: "main", name: "Uutiset",   english: "Latest news",
      url: "https://www.mtvuutiset.fi/api/feed/rss/uutiset_uusimmat" },
    { key: "all",  name: "Uusimmat",  english: "Latest from all of MTV",
      url: "https://api.mtvuutiset.fi/mtvuutiset/api/feed/rss/mtv_uusimmat_20" }
]

function byKey(key) {
    for (var i = 0; i < categories.length; i++) {
        if (categories[i].key === key) return categories[i]
    }
    return categories[0]
}

function url(category, base) {
    return base ? base + category.url.replace(/^https?:\/\/[^\/]+\//, "") : category.url
}
