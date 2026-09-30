# Yleisuutiset for Sailfish OS

An unofficial Sailfish OS reader for **Yle**, Finland's public broadcaster.
It shows the top stories from yle.fi's front page and every news category,
in the look of a native Sailfish app. Not affiliated with Yle.

- **Front page first:** the app opens on *Pääuutiset*, Yle's main headlines,
  with the top story as a big picture like on yle.fi.
- **Categories as buttons:** a row of buttons along the top, and a
  Categories page (pull down) with a big button for each:

  | Button | Content |
  |---|---|
  | Pääuutiset | Top stories from Yle's front page |
  | Tuoreimmat | Latest news |
  | Kotimaa · Ulkomaat · Politiikka · Talous | Finland · World · Politics · Business |
  | Urheilu | Sports (Yle Urheilu) |
  | Kulttuuri · Viihde · Tiede · Luonto · Terveys | Culture · Entertainment · Science · Nature · Health |
  | In English | Yle News in English |

- **Articles:** tap one for its picture, headline and lede, then *Read the
  full article* to open it on yle.fi in the browser. You can also copy the link.
- **Works offline:** every category you open is cached, so the app starts
  instantly and shows the last news when there's no connection, with a note
  saying so.
- **Remembers your category** between launches.
- **Cover:** rotates the latest headlines, with refresh and next buttons.

## Where the news comes from

Yle's official RSS feeds ([yle.fi/rss](https://yle.fi/rss),
[feeds.yle.fi/uutiset/v1](https://feeds.yle.fi/uutiset/v1)), used under
Yle's feed terms. Every article links back to yle.fi.

- Front page: `majorHeadlines/YLE_UUTISET.rss`
- Categories: `recent.rss?publisherIds=YLE_UUTISET&concepts=<Yle topic id>`,
  sports with `publisherIds=YLE_URHEILU`, English with `YLE_NEWS`

Every topic id in `qml/js/feeds.js` was checked against Yle's published
feed list.

## Privacy

The app talks to feeds.yle.fi and Yle's image server, nothing else. It runs
sandboxed (Sailjail) with only the Internet permission, and keeps its cache
in `~/.local/share/org.veetalat/yleisuutiset/`.

## Building and installing

```sh
./build-rpm.sh aarch64      # Docker; RPM lands in RPMS/
devel-su pkcon install-local ~/Downloads/harbour-yleisuutiset-1.0.0-1.aarch64.rpm
```

## Tests

```sh
node tests/test_rss.js       # RSS parsing, dates, categories
tests/sdk-smoke-test.sh      # end to end in the Sailfish SDK (Docker)
```

The parser handles every usual way RSS carries a picture (`<enclosure>`,
`media:content`, `media:thumbnail`, an `<img>` in the description), CDATA,
HTML entities and RFC 822 dates. It's plain ES5 because Sailfish's Qt 5.6
JavaScript engine is, and its `Date.parse` can't read RSS dates.

The smoke test serves the fixture feeds and pictures over HTTP and runs the
app twice on Sailfish's own Qt and Silica. It checks:

- the pages get the app's data;
- the front page and a category load;
- pictures load;
- the article and category pages open;
- a server error is shown while the news stays visible;
- after a restart, the category is remembered and the cached news shows
  without fetching.
