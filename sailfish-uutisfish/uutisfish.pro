TARGET = uutisfish

CONFIG += sailfishapp

SOURCES += \
    src/main.cpp

DISTFILES += \
    qml/uutisfish.qml \
    qml/components/ArticleItem.qml \
    qml/components/CategoryButton.qml \
    qml/cover/CoverPage.qml \
    qml/js/about.js \
    qml/js/article.js \
    qml/js/articleworker.js \
    qml/js/cache.js \
    qml/js/feeds.js \
    qml/js/rss.js \
    qml/pages/AboutPage.qml \
    qml/pages/ArticlePage.qml \
    qml/pages/CategoriesPage.qml \
    qml/pages/HomePage.qml \
    qml/pages/MainPage.qml \
    qml/pages/NewsStore.qml \
    uutisfish.desktop \
    rpm/uutisfish.spec

SAILFISHAPP_ICONS = 86x86 108x108 128x128 172x172
