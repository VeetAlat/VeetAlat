TARGET = veetpatched

CONFIG += sailfishapp

QT += quick qml gui

SOURCES += \
    src/main.cpp \
    src/patcher.cpp

HEADERS += \
    src/patcher.h

# The root helper, its systemd units, and the patches.
helper.files = helper/veetpatched-helper
helper.path = /usr/libexec/veetpatched
units.files = systemd/veetpatched.path systemd/veetpatched.service
units.path = /usr/lib/systemd/system
statusbar.files = patches/statusbar/patch.conf patches/statusbar/block.qml patches/statusbar/NotchStatusBar.qml
statusbar.path = /usr/share/veetpatched/patches/statusbar
INSTALLS += helper units statusbar

DISTFILES += \
    qml/veetpatched.qml \
    qml/cover/CoverPage.qml \
    qml/pages/AboutPage.qml \
    qml/pages/LogPage.qml \
    qml/pages/MainPage.qml \
    veetpatched.desktop \
    rpm/veetpatched.spec

SAILFISHAPP_ICONS = 86x86 108x108 128x128 172x172
