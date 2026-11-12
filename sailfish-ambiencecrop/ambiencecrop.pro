TARGET = ambiencecrop

CONFIG += sailfishapp

QT += quick qml gui dbus concurrent

SOURCES += \
    src/main.cpp \
    src/composer.cpp

HEADERS += \
    src/composer.h

DISTFILES += \
    qml/ambiencecrop.qml \
    qml/cover/CoverPage.qml \
    qml/js/layout.js \
    qml/pages/AboutPage.qml \
    qml/pages/DonePage.qml \
    qml/pages/EditorPage.qml \
    qml/pages/MainPage.qml \
    ambiencecrop.desktop \
    rpm/ambiencecrop.spec

SAILFISHAPP_ICONS = 86x86 108x108 128x128 172x172
