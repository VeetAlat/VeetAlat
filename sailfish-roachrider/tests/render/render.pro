# Screenshots of the real renderer, on the build machine's Qt and a
# virtual display. Run: tests/render-screens.sh
QT += quick
CONFIG += c++11
TARGET = render
SOURCES += render.cpp ../../src/gamecore.cpp ../../src/game.cpp ../../src/tunnelview.cpp
HEADERS += ../../src/game.h ../../src/tunnelview.h
DEFINES += SRC_DIR=\\\"$$PWD/../..\\\"
