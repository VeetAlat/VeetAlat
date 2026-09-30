import QtQuick 2.0

// One of the three game buttons: an arrow to the left or right, or the round
// jump button. Both looks are ready-made pictures (icons/make-buttons.py),
// loaded once; pressing only swaps which one shows, which costs nothing.
// (Drawing the glow live with a Canvas took seconds on a phone.)
Item {
    id: button

    property string kind: "left"    // "left", "right" or "jump"
    property bool down: false

    Image {
        anchors.fill: parent
        source: "../images/btn-" + button.kind + ".png"
        sourceSize { width: 300; height: 300 }
        smooth: true
        visible: !button.down
    }
    Image {
        anchors.fill: parent
        source: "../images/btn-" + button.kind + "-down.png"
        sourceSize { width: 300; height: 300 }
        smooth: true
        visible: button.down
    }
}
