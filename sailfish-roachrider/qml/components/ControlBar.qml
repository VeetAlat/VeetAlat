import QtQuick 2.0

// The three buttons along the bottom: left and right on the left side for
// one thumb, jump on the right for the other. They react the moment a
// finger touches them, and several fingers can press at once (steer and
// jump together).
Item {
    id: bar

    signal leftPressed()
    signal rightPressed()
    signal jumpPressed()

    readonly property real buttonSize: Math.min(height * 0.8, width * 0.27)

    NeonButton {
        id: leftButton
        kind: "left"
        width: bar.buttonSize
        height: width
        x: bar.width * 0.04
        anchors.verticalCenter: parent.verticalCenter
    }
    NeonButton {
        id: rightButton
        kind: "right"
        width: bar.buttonSize
        height: width
        x: leftButton.x + leftButton.width + bar.width * 0.02
        anchors.verticalCenter: parent.verticalCenter
    }
    NeonButton {
        id: jumpButton
        kind: "jump"
        width: bar.buttonSize * 1.1
        height: width
        x: bar.width * 0.96 - width
        anchors.verticalCenter: parent.verticalCenter
    }

    // Which button a touch at x is for. Generous: the whole bar is split
    // between the three, so a slightly missed press still counts.
    function buttonAt(x) {
        if (x > (rightButton.x + rightButton.width + jumpButton.x) / 2)
            return jumpButton
        if (x > (leftButton.x + leftButton.width + rightButton.x) / 2)
            return rightButton
        return leftButton
    }

    function press(button) {
        if (button === leftButton)
            bar.leftPressed()
        else if (button === rightButton)
            bar.rightPressed()
        else
            bar.jumpPressed()
    }

    MultiPointTouchArea {
        id: touch
        anchors.fill: parent
        maximumTouchPoints: 3

        // Touch point id -> the button it pressed.
        property var held: ({})

        function release(points) {
            for (var i = 0; i < points.length; i++) {
                var b = held[points[i].pointId]
                if (b) {
                    b.down = false
                    delete held[points[i].pointId]
                }
            }
        }

        onPressed: {
            for (var i = 0; i < touchPoints.length; i++) {
                var b = bar.buttonAt(touchPoints[i].x)
                held[touchPoints[i].pointId] = b
                b.down = true
                bar.press(b)
            }
        }
        onReleased: release(touchPoints)
        onCanceled: release(touchPoints)
    }
}
