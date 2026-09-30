TARGET = harbour-bmitracker

CONFIG += sailfishapp

SOURCES += \
    src/main.cpp

DISTFILES += \
    qml/harbour-bmitracker.qml \
    qml/components/BmiChart.qml \
    qml/components/BmiScale.qml \
    qml/components/CategoryLabel.qml \
    qml/cover/CoverPage.qml \
    qml/js/bmi.js \
    qml/js/storage.js \
    qml/pages/AddEntryDialog.qml \
    qml/pages/MainPage.qml \
    qml/pages/ProfileDialog.qml \
    qml/pages/Store.qml \
    harbour-bmitracker.desktop \
    rpm/harbour-bmitracker.spec

SAILFISHAPP_ICONS = 86x86 108x108 128x128 172x172
