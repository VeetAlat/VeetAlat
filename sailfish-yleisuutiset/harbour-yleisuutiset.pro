TARGET = harbour-yleisuutiset

CONFIG += sailfishapp

SOURCES += \
    src/main.cpp

DISTFILES += \
    qml/harbour-yleisuutiset.qml \
    qml/components/ArticleItem.qml \
    qml/components/CategoryButton.qml \
    qml/cover/CoverPage.qml \
    qml/js/cache.js \
    qml/js/feeds.js \
    qml/js/rss.js \
    qml/pages/ArticlePage.qml \
    qml/pages/CategoriesPage.qml \
    qml/pages/MainPage.qml \
    qml/pages/NewsStore.qml \
    harbour-yleisuutiset.desktop \
    rpm/harbour-yleisuutiset.spec

SAILFISHAPP_ICONS = 86x86 108x108 128x128 172x172
