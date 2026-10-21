# YleFish for Sailfish OS

A private Sailfish OS app for reading **Yle's news**, from Finland's public
broadcaster, with the **whole story and its photos inside the app**. It is
built on [UutisRSS](https://github.com/VeetAlat/sailfish-uutisrss): the same
feeds, categories, cover and offline headlines, but tapping a story opens it
in YleFish instead of the browser. Not made by or affiliated with Yle.

Made by Valatalo, for personal use.

- **Front page first:** the app opens on *Pääuutiset*, the top stories from
  Yle's front page.
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

- **Tap a story to read it** in the app: headline, time, lead, every
  paragraph and subheading, quotes, lists, and the photos with their
  captions. The feed's headline, summary and photo show at once while the
  rest loads. Pull down to open it on yle.fi, copy its link, or load it
  again. Press and hold a story in the list for the same choices.
- **Smooth while it loads:** the story's page is picked apart in a
  background thread (`qml/js/articleworker.js`), so scrolling never
  stutters. The last 30 stories you read stay in memory, so going back and
  forth is instant.
- **Never a blank page:** if the story can't be fetched or read, YleFish
  shows the feed's summary and photo and says why, with a button to open it
  on yle.fi.
- **Works offline:** the headlines of every category you open are saved on
  the phone, so the app starts instantly and shows the last headlines
  without a connection.
- **Hot news:** the first two headlines are bold and marked "Hot 🔥" while
  they're under six hours old.
- **Cover:** rotates the latest headlines with each one's date and time, with
  refresh and next buttons.
- **Icon:** a fish whose body is a news page, with a headline bar and
  columns of text, drawn by `icons/make-icon.py`.
- **About** in the pull-down menu.

## How a story is read

`qml/js/article.js` doesn't depend on one exact page layout. From the
story's page it reads:

1. the page's article markup (`<article>`, else `<main>`): paragraphs,
   subheadings, quotes, list items and `<figure>`s, picking each photo's
   phone-sized version from its `srcset` (lazy-loaded `data-src` pictures
   too) and its caption from `<figcaption>`. Navigation, share buttons,
   related links, forms and scripts are left out;
2. if the markup has too little text, the article data the page embeds for
   search engines (`application/ld+json`, `articleBody`);
3. the headline, lead, main photo and time from the page's meta tags.

> **Not yet checked against real yle.fi pages.** The build environment's
> network couldn't reach yle.fi, so the reader has only been tested on
> example pages in the usual shapes of news pages. If a real Yle story shows
> only its summary, its page is built some other way and the reader needs a
> Yle-specific step.

## For personal use only

Yle's [RSS terms of use](https://yle.fi/aihe/a/20-10008076) allow showing
headlines that link to the story on yle.fi. Showing the whole story and its
photos in an app goes beyond that, so YleFish is a private app: **don't
publish it on OpenRepos or the Jolla Store, or share it.** For an app to
share, use UutisRSS, which keeps to the terms.

It is free and non-profit, with no ads, and fetches politely: feeds only
while the app is open, at most every five minutes per category unless you
pull to refresh, and a story only when you open it.

## Privacy

YleFish runs only on your device: no account, tracking, analytics or
servers of its own. It only connects to Yle (feeds.yle.fi, yle.fi and Yle's
image server). It runs sandboxed (Sailjail) with only the Internet
permission, and keeps the headlines it fetches in
`~/.local/share/org.veetalat/ylefish/`. Whole stories are only kept in
memory. About → Delete saved news deletes everything saved.

## Made with AI-assisted tools

This app has been created using AI generated code (Claude code).

## Where the news comes from

Yle's official RSS feeds ([yle.fi/rss](https://yle.fi/rss),
[feeds.yle.fi/uutiset/v1](https://feeds.yle.fi/uutiset/v1)):

- Front page: `majorHeadlines/YLE_UUTISET.rss`
- Categories: `recent.rss?publisherIds=YLE_UUTISET&concepts=<Yle topic id>`,
  sports with `publisherIds=YLE_URHEILU`, English with `YLE_NEWS`

Each story is then read from its own page on yle.fi, the link in the feed.

## Building and installing

```sh
./build-rpm.sh aarch64      # Docker; RPM lands in RPMS/
devel-su pkcon install-local ~/Downloads/ylefish-0.1.0-1.aarch64.rpm
```

## Tests

```sh
node tests/test_rss.js       # RSS parsing, dates, categories
node tests/test_article.js   # reading a story out of its page
tests/sdk-smoke-test.sh      # end to end in the Sailfish SDK (Docker)
```

Both parsers are plain ES5, because Sailfish's Qt 5.6 JavaScript engine
is ES5 only and can't parse RSS dates.

The smoke test serves fixture feeds and an example story page over HTTP
and runs the app twice on Sailfish's own Qt and Silica. It checks:

- the front page and a category load, keeping summaries and photos;
- tapping a story opens it in the app, with the feed's headline at once,
  then the page's text, subheadings and captions in order and no page
  furniture, and its photos download;
- a story read once comes back from memory;
- a story whose page is missing shows the error with the feed's summary
  and photo;
- the About page is complete;
- errors keep the headlines visible;
- the category is remembered after a restart;
- saved headlines show before any new fetch;
- deleting saved news empties the storage.
