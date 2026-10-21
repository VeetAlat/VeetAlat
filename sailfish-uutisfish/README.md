# UutisFish for Sailfish OS

A private Sailfish OS app with **three news sources in one place**: Yle,
MTV Uutiset and AP News. It combines YleFish and MTVFish and adds AP: a
home page with a tile for each source, each source with its own headlines
by category, and every story opening **whole, with its text and photos,
inside the app**. Not made by or affiliated with Yle, MTV or the
Associated Press.

Made by Valatalo, for personal use.

## Home page

One big tile per source, in its own colour, with the source's newest saved
headline and how old it is. Tap a tile for that source's headlines; it
opens on the category you last read there. Swipe back to return home.
About is in the home page's pull-down menu.

## Sources and categories

| Source | Categories | Feeds |
|---|---|---|
| **Yle** (teal) | Pääuutiset, Tuoreimmat, Kotimaa, Ulkomaat, Politiikka, Talous, Urheilu, Kulttuuri, Viihde, Tiede, Luonto, Terveys, In English | Yle's official RSS feeds ([yle.fi/rss](https://yle.fi/rss)) |
| **MTV Uutiset** (coral) | Uutiset, Uusimmat | MTV's feeds known from feed directories, working on the phone |
| **AP News** (blue) | Top stories, Latest, U.S., World, Politics, Business, Technology, Health, Sports, Entertainment | The feeds of AP's own Flipboard magazines (AP stopped its own RSS feeds in 2024) |

Every feed is one line in `qml/js/feeds.js`. Category keys start with
their source's (`yle/main`, `ap/sports`), so each is saved separately.

## Reading a story

Tap a headline: the feed's headline, summary and photo show at once, and
the whole story loads from its own page, read in a background thread by
`qml/js/article.js` (the reader from YleFish and MTVFish). It reads the
page's story markup (`<article>`, else `<main>`: paragraphs, subheadings,
quotes, lists and photos with captions), or when that has little text, the
article data for search engines or the data a page built with JavaScript
carries (how MTV's pages work). Links to other stories are left out.

Pull down on a story to open it on its site, copy its link or load it
again. Feed links lose the tracking tags some feeds add (`utm_...`). If a story's text isn't found, **Copy page report** copies a short
description of how its page is built, to paste to whoever fixes the
reader.

The rest is as in YleFish and MTVFish: headlines saved for offline
reading and a quick start, "Hot 🔥" on fresh top headlines, the last 30
stories kept in memory, and a cover with the latest headlines.

> **AP's stories open as their summary.** AP's headlines work, but
> apnews.com answers anything that isn't a web browser with a Cloudflare
> check ("Just a moment...") instead of the story, and UutisFish doesn't
> try to get around it. So an AP story shows the feed's headline, summary
> and photo, says why, and has a button to read it on apnews.com. The app
> remembers this for the session, so the next AP story opens at once;
> "Load again" tries the site again.

## For personal use only

Showing whole stories and their photos goes beyond what news feeds are
offered for (Yle's [RSS terms](https://yle.fi/aihe/a/20-10008076), for
one, only allow headlines that link to yle.fi), so UutisFish is for your
own reading: **don't publish it on OpenRepos or the Jolla Store, or share
it.** It is free and non-profit, with no ads, and fetches politely: feeds
only while the app is open, at most every five minutes per category unless
you pull to refresh, and a story only when you open it.

## Privacy

UutisFish runs only on your device: no account, tracking, analytics or
servers of its own. It only connects to the three sources (and Flipboard,
for AP's feeds). It runs sandboxed (Sailjail) with only the Internet
permission, and keeps the headlines it fetches in
`~/.local/share/org.veetalat/uutisfish/`. Whole stories are only kept in
memory. About → Delete saved news deletes everything saved.

## Made with AI-assisted tools

This app has been created using AI generated code (Claude code).

## Icon

A little school of three newspaper fish, one per source, in the home
page's colours, drawn by `icons/make-icon.py`.

## Building and installing

```sh
./build-rpm.sh aarch64      # Docker; RPM lands in RPMS/
devel-su pkcon install-local ~/Downloads/uutisfish-0.1.1-1.aarch64.rpm
```

UutisFish installs next to YleFish and MTVFish; they don't share anything,
so you can keep or remove them.

## Tests

```sh
node tests/test_rss.js       # RSS parsing, dates, sources and feeds
node tests/test_article.js   # reading a story out of its page
tests/sdk-smoke-test.sh      # end to end in the Sailfish SDK (Docker)
```

The smoke test serves example feeds and story pages for all three sources
and runs the app twice on Sailfish's own Qt and Silica. Run 1 starts on
the home page and goes through Yle (headlines, a story with its text and
photos, a missing story, another category, a feed error), MTV Uutiset (a
story built from the page's data) and AP News (a story in plain `<div>`s,
and stories whose site answers with a browser check: the test server
answers a page with a `.status` file next to it with that status).
Run 2 checks the last category is remembered, the home page shows each
source's saved headline, each source reopens on its last category, and
deleting saved news empties everything.
