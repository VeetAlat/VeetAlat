# UutisRSS for Sailfish OS

An unofficial Sailfish OS app for the latest **headlines from Yle**, Finland's
public broadcaster, from Yle's public RSS feeds. Tap a headline to read the
story on yle.fi. Not made by or affiliated with Yle.

Made by Valatalo.

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

- **Tap a headline** to open the story on yle.fi. Press and hold to copy
  its link.
- **Works offline:** the headlines of every category you open are saved on
  the phone, so the app starts instantly and shows the last headlines
  without a connection.
- **Cover:** rotates the latest headlines, with refresh and next buttons.
- **About and disclaimers** in the pull-down menu.

## Following Yle's RSS terms

Yle's [RSS terms of use](https://yle.fi/aihe/a/20-10008076) (updated
15 Nov 2024) allow showing headlines from the feed, with each one linking
directly to the story on Yle's site. They forbid copying other content,
using the stories' photos, and paid services, apps or advertising. So
UutisRSS:

- **shows headlines only.** Photos and summaries in the feed are dropped
  before anything is shown or saved (`headlinesOnly()` in
  `qml/pages/NewsStore.qml`), and no photo is ever downloaded;
- **opens every headline straight on yle.fi**, in the browser. There is no
  in-app copy of the story;
- **is free and non-profit**, with no ads or paid features;
- **lets you delete all saved headlines** (About → Delete saved headlines),
  since Yle may ask users to delete the content;
- **fetches politely:** only while the app is open, at most every five
  minutes per category unless you pull to refresh.

The smoke test enforces the first two points: it serves feeds that contain
photos and summaries, and fails if the app keeps them or downloads a single
photo.

## Privacy

UutisRSS runs only on your device: no account, tracking, analytics or
servers of its own. Its only connection is to feeds.yle.fi. It runs sandboxed
(Sailjail) with only the Internet permission, and keeps its saved headlines
in `~/.local/share/org.veetalat/uutisrss/`.

## Made with AI-assisted tools

UutisRSS was made with the help of AI-assisted tools (Claude Code).

## Where the headlines come from

Yle's official RSS feeds ([yle.fi/rss](https://yle.fi/rss),
[feeds.yle.fi/uutiset/v1](https://feeds.yle.fi/uutiset/v1)):

- Front page: `majorHeadlines/YLE_UUTISET.rss`
- Categories: `recent.rss?publisherIds=YLE_UUTISET&concepts=<Yle topic id>`,
  sports with `publisherIds=YLE_URHEILU`, English with `YLE_NEWS`

Every topic id in `qml/js/feeds.js` was checked against Yle's published
feed list.

## OpenRepos link

Set `OPENREPOS_URL` in `qml/js/about.js` to your OpenRepos profile. The About
page then shows a "More apps on OpenRepos" button under "Made by Valatalo".

## Building and installing

```sh
./build-rpm.sh aarch64      # Docker; RPM lands in RPMS/
devel-su pkcon install-local ~/Downloads/harbour-uutisrss-1.0.0-1.aarch64.rpm
```

## Tests

```sh
node tests/test_rss.js       # RSS parsing, dates, categories
tests/sdk-smoke-test.sh      # end to end in the Sailfish SDK (Docker)
```

The parser handles CDATA, HTML entities and RFC 822 dates in plain ES5,
because Sailfish's Qt 5.6 JavaScript engine can't parse RSS dates. It also
recognises every usual way RSS attaches a picture, but only so they can be
recognised and dropped.

The smoke test serves fixture feeds over HTTP and runs the app twice on
Sailfish's own Qt and Silica. It checks:

- the front page and a category load;
- only headlines are kept and no photo is downloaded;
- tapping a headline opens its yle.fi link;
- the About page is complete;
- errors keep the headlines visible;
- the category is remembered after a restart;
- saved headlines show before any fetch;
- deleting saved headlines empties the storage.
