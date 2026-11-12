/*
 * StatusBar, a Patchmanager patch for Sailfish OS: a black bar over the
 * screen's notch while an app is open, showing the time and the status
 * icons the home screen shows, like Android apps get.
 *
 * Loaded by the patched AppLayer.qml into the app layer's overlay, so it
 * sits above the app and moves with it when you swipe to peek. Shown only
 * with the phone upright (that's where the notch is on top); turned
 * sideways, apps get the whole screen as before.
 *
 * This file is loaded through a Loader: if it fails on some Sailfish
 * version, there's just no bar, and apps work as without the patch.
 */
import QtQuick 2.6
import Sailfish.Silica 1.0
import Sailfish.Lipstick 1.0
import org.nemomobile.lipstick 0.1
import com.jolla.lipstick 0.1
import "file:///usr/share/lipstick-jolla-home-qt5/statusarea"

Item {
    id: bar

    // The app layer, from the Loader in AppLayer.qml.
    readonly property Item hostLayer: parent ? parent.hostLayer : null
    readonly property bool upright: Lipstick.compositor.topmostWindowOrientation === Qt.PortraitOrientation
    readonly property real notchHeight: Screen.hasCutouts ? Screen.topCutout.height : 0

    width: parent ? parent.width : 0
    height: notchHeight
    visible: notchHeight > 0 && upright && hostLayer !== null && hostLayer.window !== null && hostLayer.window !== undefined

    Rectangle {
        anchors.fill: parent
        color: "black"
    }

    // The home screen's own status icons (battery, profile, Bluetooth, Wi-Fi,
    // mobile signal), centred in the bar. In lock screen mode it leaves out
    // its own clock, which would go below the notch; ours goes beside it.
    StatusArea {
        id: status

        // Its icon row is as tall as the battery; its height adds the notch.
        y: Math.round((bar.height - (status.height - bar.notchHeight)) / 2)
        color: "white"
        lockscreenMode: true
        updatesEnabled: bar.visible
    }

    ClockItem {
        id: clock

        // Just left of the notch, or at the left edge if the notch is there.
        x: Screen.topCutout.x > clock.width + 2 * Theme.paddingLarge
           ? Screen.topCutout.x - clock.width - Theme.paddingLarge
           : Theme.paddingLarge
        anchors.verticalCenter: parent.verticalCenter
        updatesEnabled: bar.visible
        color: "white"
        font { pixelSize: Theme.fontSizeSmall; family: Theme.fontFamilyHeading }

        Connections {
            target: Lipstick.compositor
            onDisplayAboutToBeOn: clock.forceUpdate()
        }
    }
}
