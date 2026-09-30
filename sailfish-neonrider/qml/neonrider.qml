import QtQuick 2.0
import Sailfish.Silica 1.0
import "pages"
import "cover"

// gameEngine (the Game object) comes from main.cpp.
ApplicationWindow {
    id: app

    initialPage: Component { GamePage { } }
    cover: Component { CoverPage { } }
    allowedOrientations: Orientation.Portrait

    // Leaving the app (or the screen going off) pauses the ride.
    Connections {
        target: Qt.application
        onActiveChanged: if (!Qt.application.active) gameEngine.paused = true
    }
}
