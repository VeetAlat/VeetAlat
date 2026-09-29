TARGET = nr-mode

CONFIG += sailfishapp

SOURCES += \
    src/main.cpp \
    src/nrcontrol.cpp

HEADERS += \
    src/nrcontrol.h

DISTFILES += \
    qml/nr-mode.qml \
    qml/cover/CoverPage.qml \
    qml/pages/CellMonitor.qml \
    qml/pages/ContextItem.qml \
    qml/pages/DiagnosticsPage.qml \
    qml/pages/EventLog.qml \
    qml/pages/MainPage.qml \
    qml/pages/MonitorPage.qml \
    qml/pages/Network.qml \
    nr-mode.desktop \
    rpm/nr-mode.spec

SAILFISHAPP_ICONS = 86x86 108x108 128x128 172x172

helper.files = helper/nr-mode-helper
helper.path = /usr/libexec/nr-mode

units.files = systemd/nr-mode-apply.path systemd/nr-mode-apply.service
units.path = /usr/lib/systemd/system

tmpfiles.files = systemd/tmpfiles.d/nr-mode.conf
tmpfiles.path = /usr/lib/tmpfiles.d

INSTALLS += helper units tmpfiles
