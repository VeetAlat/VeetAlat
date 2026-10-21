.pragma library

// The news sources and their feeds. Each category's key starts with its
// source's ("yle/main"), so keys are unique across the app.
//
// Yle: Yle's official RSS feeds (https://yle.fi/rss); categories are Yle's
// own topic ids ("concepts"), checked against Yle's published feed list.
// MTV Uutiset: the two feeds known from feed directories (MTV's own list
// couldn't be reached while building), both working on the phone.
// AP News: AP stopped its own RSS feeds in 2024; these are the feeds of
// AP's own Flipboard magazines, one per section.
//
// base can be overridden (tests serve local fixtures): a feed's address is
// then fetched from there, minus its host.

var DEFAULT_BASE = ""

var sources = [
    { key: "yle", name: "Yle", full: "Yle Uutiset", site: "yle.fi", home: "https://yle.fi/",
      about: "Finland's public broadcaster",
      color: "#16b3c4",
      categories: [
        { key: "yle/main",     name: "Pääuutiset", english: "Top stories",
          url: "https://feeds.yle.fi/uutiset/v1/majorHeadlines/YLE_UUTISET.rss" },
        { key: "yle/latest",   name: "Tuoreimmat", english: "Latest",
          url: "https://feeds.yle.fi/uutiset/v1/recent.rss?publisherIds=YLE_UUTISET" },
        { key: "yle/kotimaa",  name: "Kotimaa",    english: "Finland",
          url: "https://feeds.yle.fi/uutiset/v1/recent.rss?publisherIds=YLE_UUTISET&concepts=18-34837" },
        { key: "yle/ulkomaat", name: "Ulkomaat",   english: "World",
          url: "https://feeds.yle.fi/uutiset/v1/recent.rss?publisherIds=YLE_UUTISET&concepts=18-34953" },
        { key: "yle/politiikka", name: "Politiikka", english: "Politics",
          url: "https://feeds.yle.fi/uutiset/v1/recent.rss?publisherIds=YLE_UUTISET&concepts=18-38033" },
        { key: "yle/talous",   name: "Talous",     english: "Business",
          url: "https://feeds.yle.fi/uutiset/v1/recent.rss?publisherIds=YLE_UUTISET&concepts=18-19274" },
        { key: "yle/urheilu",  name: "Urheilu",    english: "Sports",
          url: "https://feeds.yle.fi/uutiset/v1/recent.rss?publisherIds=YLE_URHEILU" },
        { key: "yle/kulttuuri", name: "Kulttuuri", english: "Culture",
          url: "https://feeds.yle.fi/uutiset/v1/recent.rss?publisherIds=YLE_UUTISET&concepts=18-150067" },
        { key: "yle/viihde",   name: "Viihde",     english: "Entertainment",
          url: "https://feeds.yle.fi/uutiset/v1/recent.rss?publisherIds=YLE_UUTISET&concepts=18-36066" },
        { key: "yle/tiede",    name: "Tiede",      english: "Science",
          url: "https://feeds.yle.fi/uutiset/v1/recent.rss?publisherIds=YLE_UUTISET&concepts=18-819" },
        { key: "yle/luonto",   name: "Luonto",     english: "Nature",
          url: "https://feeds.yle.fi/uutiset/v1/recent.rss?publisherIds=YLE_UUTISET&concepts=18-35354" },
        { key: "yle/terveys",  name: "Terveys",    english: "Health",
          url: "https://feeds.yle.fi/uutiset/v1/recent.rss?publisherIds=YLE_UUTISET&concepts=18-35138" },
        { key: "yle/english",  name: "In English", english: "Yle News",
          url: "https://feeds.yle.fi/uutiset/v1/recent.rss?publisherIds=YLE_NEWS" }
      ] },
    { key: "mtv", name: "MTV Uutiset", full: "MTV Uutiset", site: "mtvuutiset.fi", home: "https://www.mtvuutiset.fi/",
      about: "Finland's commercial TV news",
      color: "#ff6f4f",
      categories: [
        { key: "mtv/main", name: "Uutiset",  english: "Latest news",
          url: "https://www.mtvuutiset.fi/api/feed/rss/uutiset_uusimmat" },
        { key: "mtv/all",  name: "Uusimmat", english: "Latest from all of MTV",
          url: "https://api.mtvuutiset.fi/mtvuutiset/api/feed/rss/mtv_uusimmat_20" }
      ] },
    { key: "ap", name: "AP News", full: "AP News", site: "apnews.com", home: "https://apnews.com/",
      about: "The Associated Press, in English",
      color: "#3f6fd8",
      categories: [
        { key: "ap/top",      name: "Top stories",   english: "Top stories",
          url: "https://flipboard.com/@associatedpress/top-stories-u7govdf1z.rss" },
        { key: "ap/latest",   name: "Latest",        english: "Latest from all sections",
          url: "https://flipboard.com/@AssociatedPress.rss" },
        { key: "ap/us",       name: "U.S.",          english: "U.S. news",
          url: "https://flipboard.com/@associatedpress/u.s.-news-lhl4uphvz.rss" },
        { key: "ap/world",    name: "World",         english: "International news",
          url: "https://flipboard.com/@associatedpress/international-news-miluvhmaz.rss" },
        { key: "ap/politics", name: "Politics",      english: "Politics",
          url: "https://flipboard.com/@associatedpress/politics-h8vn14lnz.rss" },
        { key: "ap/business", name: "Business",      english: "Business and finance",
          url: "https://flipboard.com/@associatedpress/business-and-finance-pbj3bpclz.rss" },
        { key: "ap/tech",     name: "Technology",    english: "Technology",
          url: "https://flipboard.com/@associatedpress/technology-uvt65hdqz.rss" },
        { key: "ap/health",   name: "Health",        english: "Health",
          url: "https://flipboard.com/@associatedpress/health-l59qepnvz.rss" },
        { key: "ap/sports",   name: "Sports",        english: "Sports",
          url: "https://flipboard.com/@associatedpress/sports-uv5v9mtcz.rss" },
        { key: "ap/entertainment", name: "Entertainment", english: "Entertainment",
          url: "https://flipboard.com/@associatedpress/entertainment-qju7ofhsz.rss" }
      ] }
]

function source(key) {
    var k = String(key || "").split("/")[0]
    for (var i = 0; i < sources.length; i++) {
        if (sources[i].key === k) return sources[i]
    }
    return sources[0]
}

// The category with this key, or its source's first (or Yle's front page).
function byKey(key) {
    var src = source(key)
    for (var i = 0; i < src.categories.length; i++) {
        if (src.categories[i].key === key) return src.categories[i]
    }
    return src.categories[0]
}

function url(category, base) {
    return base ? base + category.url.replace(/^https?:\/\/[^\/]+\//, "") : category.url
}
