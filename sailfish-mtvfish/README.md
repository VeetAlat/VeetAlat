# MTVFish for Sailfish OS

A private Sailfish OS app for reading **MTV Uutiset's news**, with the
**whole story and its photos inside the app**. It is YleFish's sibling: the
same reader, cover and offline headlines, fed by MTV Uutiset's RSS feeds.
Not made by or affiliated with MTV.

Made by Valatalo, for personal use.

- **Two feeds as buttons:**

  | Button | Feed |
  |---|---|
  | Uutiset | MTV Uutiset's latest news (`www.mtvuutiset.fi/api/feed/rss/uutiset_uusimmat`) |
  | Uusimmat | The latest 20 stories from all of mtvuutiset.fi (`api.mtvuutiset.fi/mtvuutiset/api/feed/rss/mtv_uusimmat_20`) |

  MTV doesn't publish a feed list that could be reached while building
  this, so these two come from feed directories. More categories are one
  line each in `qml/js/feeds.js` once their addresses are known.
- **Tap a story to read it** in the app: headline, time, lead, every
  paragraph and subheading, quotes, lists, and the photos with their
  captions. The feed's headline, summary and photo show at once while the
  rest loads. Pull down to open it on mtvuutiset.fi, copy its link, or load
  it again. Press and hold a story in the list for the same choices.
- **Smooth while it loads:** the story's page is picked apart in a
  background thread (`qml/js/articleworker.js`). The last 30 stories you
  read stay in memory.
- **Never a blank page:** if the story can't be fetched or read, MTVFish
  shows the feed's summary and photo and says why, with a button to open it
  on mtvuutiset.fi.
- **Works offline:** the headlines of each feed you open are saved on the
  phone, so the app starts instantly and shows the last headlines without a
  connection.
- **Hot news:** the first two headlines are bold and marked "Hot 🔥" while
  they're under six hours old.
- **Cover:** rotates the latest headlines with refresh and next buttons.
- **Icon:** a fish whose body is an old TV set showing the news, with an
  antenna for a fin, drawn by `icons/make-icon.py`.

## How a story is read

`qml/js/article.js` (shared with YleFish) doesn't depend on one exact page
layout. From the story's page it reads the article markup (`<article>`,
else `<main>`): paragraphs, subheadings, quotes, list items and
`<figure>`s with their photos and captions, leaving out navigation, share
buttons and related links. When the markup has too little text, it uses the
article data the page embeds for search engines (`application/ld+json`).
The headline, lead, main photo and time come from the page's meta tags.

When the markup has little text, it also looks through the data a page
built with JavaScript carries (Next.js's `__NEXT_DATA__`, other
`application/json` scripts and `window.__STATE__ = {...}`) for the fullest
story there: typed blocks (paragraphs with their spans, subheadings,
quotes, pictures), Draft.js blocks or HTML. "Read also" stories nested in
the story's `<article>` are left out instead of cutting it short.

If a story's text still isn't found, its pull-down menu has **Copy page
report**: a short description of how the page is built (its tags, embedded
data and where the long texts are in it, and the markup from the headline
on). Paste it to whoever is fixing the reader.

> **Not yet checked against real MTV Uutiset pages or feeds.** The build
> environment's network couldn't reach mtvuutiset.fi, so the feeds'
> addresses are unconfirmed and the reader has only been tested on example
> pages. If a real story shows only its summary, its page is built some
> other way and the reader needs an MTV-specific step.

## For personal use only

Showing MTV Uutiset's whole stories and photos in an app is for your own
reading only: **don't publish it on OpenRepos or the Jolla Store, or share
it.** It is free and non-profit, with no ads, and fetches politely: feeds
only while the app is open, at most every five minutes per feed unless you
pull to refresh, and a story only when you open it.

## Privacy

MTVFish runs only on your device: no account, tracking, analytics or
servers of its own. It only connects to MTV Uutiset. It runs sandboxed
(Sailjail) with only the Internet permission, and keeps the headlines it
fetches in `~/.local/share/org.veetalat/mtvfish/`. Whole stories are only
kept in memory. About → Delete saved news deletes everything saved.

## Made with AI-assisted tools

This app has been created using AI generated code (Claude code).

## Building and installing

```sh
./build-rpm.sh aarch64      # Docker; RPM lands in RPMS/
devel-su pkcon install-local ~/Downloads/mtvfish-0.1.1-1.aarch64.rpm
```

## Tests

```sh
node tests/test_rss.js       # RSS parsing, dates, feeds
node tests/test_article.js   # reading a story out of its page
tests/sdk-smoke-test.sh      # end to end in the Sailfish SDK (Docker)
```

The smoke test serves example feeds and an example story page over HTTP
and runs the app twice on Sailfish's own Qt and Silica. It checks the
feeds load, tapping a story opens it in the app with its text, subheadings,
captions and photos, a missing story falls back to the feed's summary and
photo, the About page, errors keep the headlines visible, the feed is
remembered after a restart, and deleting saved news empties the storage.
