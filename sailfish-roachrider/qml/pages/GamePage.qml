import QtQuick 2.0
import Sailfish.Silica 1.0
import RoachRider 1.0
import "../components"

// The whole game on one page: the tunnel, the distance, the three buttons,
// and the start, pause and game over menus over the tunnel.
Page {
    id: page

    readonly property bool playing: gameEngine.state === Game.Running && !gameEngine.paused
    readonly property bool menuShown: !playing

    allowedOrientations: Orientation.Portrait

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: "#05010f" }
            GradientStop { position: 0.4; color: "#170530" }
            GradientStop { position: 1; color: "#05010f" }
        }
    }

    TunnelView {
        id: tunnel
        bikeSource: Qt.resolvedUrl("../images/roach-back.png")
        // On the start screen the roach is in the menu instead.
        showBike: gameEngine.state !== Game.Ready
        anchors { left: parent.left; right: parent.right; top: parent.top; bottom: controls.top }
        clip: true
        game: gameEngine
    }

    GameSounds {
        riding: page.playing
        speed: gameEngine.speed
    }

    // A red flash when the ride ends.
    Rectangle {
        id: flash
        anchors.fill: tunnel
        color: "#ff2d55"
        opacity: 0
        NumberAnimation on opacity { id: flashAnimation; running: false; from: 0.55; to: 0; duration: 450 }
    }
    Connections {
        target: gameEngine
        onStateChanged: if (gameEngine.state === Game.Over) flashAnimation.restart()
    }

    // Distance, and a pause button.
    Label {
        id: distance
        anchors { left: parent.left; top: parent.top; margins: Theme.horizontalPageMargin }
        visible: gameEngine.state !== Game.Ready
        font.pixelSize: Theme.fontSizeExtraLarge
        font.bold: true
        color: "#ffffff"
        text: gameEngine.score + " m"
    }
    Label {
        anchors { left: distance.left; top: distance.bottom }
        visible: distance.visible && gameEngine.best > 0
        font.pixelSize: Theme.fontSizeSmall
        color: "#19c6ff"
        text: "Best " + gameEngine.best + " m"
    }
    MouseArea {
        id: pauseButton
        anchors { right: parent.right; top: parent.top }
        width: Theme.itemSizeLarge
        height: width
        visible: page.playing
        onClicked: gameEngine.paused = true

        Row {
            anchors.centerIn: parent
            spacing: Theme.paddingSmall
            Repeater {
                model: 2
                Rectangle {
                    width: Theme.paddingSmall * 1.5
                    height: Theme.iconSizeSmall
                    radius: 2
                    color: pauseButton.pressed ? "#ffffff" : "#19c6ff"
                }
            }
        }
    }

    ControlBar {
        id: controls
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: Math.round(page.height * 0.17)
        enabled: page.playing
        opacity: page.playing ? 1 : 0.35
        onLeftPressed: gameEngine.left()
        onRightPressed: gameEngine.right()
        onJumpPressed: gameEngine.jump()
    }

    // A keyboard works too, for the emulator: arrows and space.
    Item {
        focus: true
        Keys.onPressed: {
            if (event.isAutoRepeat)
                return
            if (event.key === Qt.Key_Left) gameEngine.left()
            else if (event.key === Qt.Key_Right) gameEngine.right()
            else if (event.key === Qt.Key_Space || event.key === Qt.Key_Up) gameEngine.jump()
            else return
            event.accepted = true
        }
    }

    // Start, pause and game over.
    Rectangle {
        id: menu
        anchors.fill: tunnel
        visible: page.menuShown
        color: Qt.rgba(0.02, 0.0, 0.07, 0.72)

        // Swallow taps so they don't reach the game underneath.
        MouseArea { anchors.fill: parent }

        Column {
            id: menuColumn
            anchors.centerIn: parent
            width: parent.width - 2 * Theme.horizontalPageMargin
            spacing: Theme.paddingLarge

            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: Theme.fontSizeHuge
                font.bold: true
                color: "#ff2bd6"
                text: gameEngine.state === Game.Over ? "GAME OVER"
                    : gameEngine.paused ? "PAUSED" : "ROACH RIDER"
            }
            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                visible: gameEngine.state === Game.Over
                color: "#ffffff"
                text: gameEngine.deathReason
            }
            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                visible: gameEngine.state === Game.Over
                font.pixelSize: Theme.fontSizeExtraLarge
                color: "#19c6ff"
                text: gameEngine.score + " m" + (gameEngine.newBest ? "  ·  New best!" : "")
            }
            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                visible: gameEngine.state === Game.Ready && gameEngine.best > 0
                color: "#19c6ff"
                text: "Best " + gameEngine.best + " m"
            }
            // The roach, turned towards you, bobbing gently on its bike.
            Image {
                id: roach
                anchors.horizontalCenter: parent.horizontalCenter
                visible: gameEngine.state === Game.Ready
                width: Math.min(parent.width, page.height * 0.42)
                height: width
                source: "../images/roach-menu.png"
                sourceSize { width: 720; height: 720 }
                smooth: true
                transform: Translate { id: bob }
                SequentialAnimation {
                    running: roach.visible && Qt.application.active
                    loops: Animation.Infinite
                    NumberAnimation { target: bob; property: "y"; to: -Theme.paddingMedium; duration: 900; easing.type: Easing.InOutSine }
                    NumberAnimation { target: bob; property: "y"; to: 0; duration: 900; easing.type: Easing.InOutSine }
                }
            }

            Item { width: 1; height: Theme.paddingMedium }

            Button {
                id: playButton
                anchors.horizontalCenter: parent.horizontalCenter
                preferredWidth: Theme.buttonWidthLarge
                text: gameEngine.paused ? "Continue"
                    : gameEngine.state === Game.Over ? "Play again" : "Play"
                onClicked: {
                    if (gameEngine.paused)
                        gameEngine.paused = false
                    else
                        gameEngine.start()
                }
            }
            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                preferredWidth: Theme.buttonWidthLarge
                visible: gameEngine.paused || gameEngine.state === Game.Over
                text: "Menu"
                onClicked: gameEngine.quit()
            }
            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                preferredWidth: Theme.buttonWidthLarge
                visible: gameEngine.state === Game.Ready
                text: "About"
                onClicked: pageStack.push(Qt.resolvedUrl("AboutPage.qml"))
            }
        }
    }
}
