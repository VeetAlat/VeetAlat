TARGET = neonrider

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
    qml/neonrider.qml \
    qml/components/ColorPicker.qml \
    qml/components/ControlBar.qml \
    qml/components/NeonButton.qml \
    qml/cover/CoverPage.qml \
    qml/js/about.js \
    qml/pages/AboutPage.qml \
    qml/pages/GamePage.qml \
    neonrider.desktop \
    rpm/neonrider.spec

SAILFISHAPP_ICONS = 86x86 108x108 128x128 172x172
