# Game rules and track tests, built with the build machine's Qt.
QT += testlib
QT -= gui
CONFIG += c++11 console
TARGET = tst_game
SOURCES += tst_game.cpp ../../src/gamecore.cpp ../../src/game.cpp
HEADERS += ../../src/game.h
