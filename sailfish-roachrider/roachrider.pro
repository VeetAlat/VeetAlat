TARGET = roachrider

CONFIG += sailfishapp c++11

SOURCES += \
    src/main.cpp \
    src/gamecore.cpp \
    src/game.cpp \
    src/tunnelview.cpp

HEADERS += \
    src/gamecore.h \
    src/game.h \
    src/tunnelview.h

DISTFILES += \
    qml/roachrider.qml \
    qml/components/ControlBar.qml \
    qml/components/GameSounds.qml \
    qml/components/NeonButton.qml \
    qml/cover/CoverPage.qml \
    qml/images/*.png \
    qml/sounds/*.wav \
    qml/js/about.js \
    qml/pages/AboutPage.qml \
    qml/pages/GamePage.qml \
    roachrider.desktop \
    rpm/roachrider.spec

SAILFISHAPP_ICONS = 86x86 108x108 128x128 172x172
