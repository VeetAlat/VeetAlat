import QtQuick 2.6
import Sailfish.Silica 1.0

// A stand-in for the home screen's StatusArea, built the same way as the
// real one (lipstick-jolla-home-qt5/statusarea/StatusArea.qml): a row of
// icons from the left corner and one anchored to the right corner, as tall
// as the battery plus the notch. The icons are boxes of their usual sizes;
// the test's Loader says how many there are.
Item {
    id: statusArea

    property bool updatesEnabled: true
    property bool lockscreenMode
    property color color: Theme.primaryColor
    readonly property var fake: parent && parent.parent ? parent.parent.fake : ({})
    property int cornerPadding: fake.corner

    width: parent.width
    height: iconBar.height

    Item {
        id: iconBar
        width: parent.width
        height: battery.height + statusArea.parent.notchHeight

        Row {
            objectName: "leftIndicators"
            x: statusArea.cornerPadding
            height: battery.height
            spacing: Theme.paddingSmall

            // The battery icon and its percentage (the SDK loads no fonts
            // for this test, so the text is a box as wide as "85%" or "100%").
            Rectangle {
                id: battery
                objectName: "battery"
                property bool usbPreparingMode   // as the real BatteryStatusIndicator has
                width: Theme.iconSizeExtraSmall / 2 + Theme.paddingSmall + statusArea.fake.battery
                height: Theme.iconSizeExtraSmall
                color: "#44aa44"
            }
            Repeater {
                model: statusArea.fake.left
                Rectangle { width: Theme.iconSizeExtraSmall; height: width; color: "#4477cc"; anchors.verticalCenter: parent.verticalCenter }
            }
        }

        Row {
            objectName: "rightIndicators"
            height: battery.height
            spacing: Theme.paddingSmall
            anchors { right: parent.right; rightMargin: statusArea.cornerPadding }
            Repeater {
                model: statusArea.fake.right
                Rectangle { width: Theme.iconSizeExtraSmall; height: width; color: "#cc7744"; anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }
}
