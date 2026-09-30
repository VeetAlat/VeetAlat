import QtQuick 2.0
import Sailfish.Silica 1.0
import "pages"
import "cover"
import "js/feeds.js" as Feeds

ApplicationWindow {
    id: app

    // Named "newsStore", not "news": pages have a "news" property, and
    // "MainPage { news: news }" would bind the page to its own empty
    // property instead of this object.
    NewsStore {
        id: newsStore
        // feedBaseOverride comes from main.cpp (empty unless testing).
        feedBase: feedBaseOverride !== "" ? feedBaseOverride : Feeds.DEFAULT_BASE
    }

    initialPage: Component {
        MainPage { news: newsStore }
    }
    cover: Component {
        CoverPage { news: newsStore }
    }
    allowedOrientations: defaultAllowedOrientations
}
