TARGET = codesysfish

CONFIG += sailfishapp

QT += quick qml gui

SOURCES += \
    src/main.cpp \
    src/sthighlighter.cpp

HEADERS += \
    src/sthighlighter.h

DISTFILES += \
    qml/codesysfish.qml \
    qml/cover/CoverPage.qml \
    qml/js/about.js \
    qml/js/examples.js \
    qml/js/reference.js \
    qml/js/st.js \
    qml/js/store.js \
    qml/pages/AboutPage.qml \
    qml/pages/EditorPage.qml \
    qml/pages/HelpPage.qml \
    qml/pages/NewProjectDialog.qml \
    qml/pages/Plc.qml \
    qml/pages/ProjectsPage.qml \
    qml/pages/RenameDialog.qml \
    qml/pages/RunPage.qml \
    qml/pages/WriteDialog.qml \
    codesysfish.desktop \
    rpm/codesysfish.spec

SAILFISHAPP_ICONS = 86x86 108x108 128x128 172x172
