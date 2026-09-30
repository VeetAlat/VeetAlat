.pragma library

// Yle's official RSS feeds (https://yle.fi/rss, https://feeds.yle.fi/uutiset/v1).
// Categories are Yle's own topic ids ("concepts"), each checked against
// Yle's published feed list.
//
// base can be overridden (tests serve local fixtures).

var DEFAULT_BASE = "https://feeds.yle.fi/uutiset/v1/"

var categories = [
    { key: "main",     name: "Pääuutiset", english: "Top stories",       path: "majorHeadlines/YLE_UUTISET.rss" },
    { key: "latest",   name: "Tuoreimmat", english: "Latest",            path: "recent.rss?publisherIds=YLE_UUTISET" },
    { key: "kotimaa",  name: "Kotimaa",    english: "Finland",           path: "recent.rss?publisherIds=YLE_UUTISET&concepts=18-34837" },
    { key: "ulkomaat", name: "Ulkomaat",   english: "World",             path: "recent.rss?publisherIds=YLE_UUTISET&concepts=18-34953" },
    { key: "politiikka", name: "Politiikka", english: "Politics",        path: "recent.rss?publisherIds=YLE_UUTISET&concepts=18-38033" },
    { key: "talous",   name: "Talous",     english: "Business",          path: "recent.rss?publisherIds=YLE_UUTISET&concepts=18-19274" },
    { key: "urheilu",  name: "Urheilu",    english: "Sports",            path: "recent.rss?publisherIds=YLE_URHEILU" },
    { key: "kulttuuri", name: "Kulttuuri", english: "Culture",           path: "recent.rss?publisherIds=YLE_UUTISET&concepts=18-150067" },
    { key: "viihde",   name: "Viihde",     english: "Entertainment",     path: "recent.rss?publisherIds=YLE_UUTISET&concepts=18-36066" },
    { key: "tiede",    name: "Tiede",      english: "Science",           path: "recent.rss?publisherIds=YLE_UUTISET&concepts=18-819" },
    { key: "luonto",   name: "Luonto",     english: "Nature",            path: "recent.rss?publisherIds=YLE_UUTISET&concepts=18-35354" },
    { key: "terveys",  name: "Terveys",    english: "Health",            path: "recent.rss?publisherIds=YLE_UUTISET&concepts=18-35138" },
    { key: "english",  name: "In English", english: "Yle News",          path: "recent.rss?publisherIds=YLE_NEWS" }
]

function byKey(key) {
    for (var i = 0; i < categories.length; i++) {
        if (categories[i].key === key) return categories[i]
    }
    return categories[0]
}

function url(category, base) {
    return (base || DEFAULT_BASE) + category.path
}
