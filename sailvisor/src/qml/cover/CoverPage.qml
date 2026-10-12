import QtQuick 2.0
import Sailfish.Silica 1.0

CoverBackground {
    id: cover

    property var backend
    property int running: 0
    property int total: 0

    function refresh() {
        if (!backend || !backend.ready) return
        backend.run("list_vms", [], function(vms) {
            var n = 0
            for (var i = 0; i < vms.length; i++)
                if (vms[i].state === "running" || vms[i].state === "starting") n++
            running = n
            total = vms.length
        }, function() {})
    }

    Timer {
        interval: 3000
        repeat: true
        triggeredOnStart: true
        running: cover.status === Cover.Active
        onTriggered: cover.refresh()
    }

    Column {
        anchors.centerIn: parent
        width: parent.width - 2 * Theme.paddingLarge
        spacing: Theme.paddingMedium

        Image {
            anchors.horizontalCenter: parent.horizontalCenter
            source: "/usr/share/icons/hicolor/128x128/apps/sailvisor.png"
            width: Theme.iconSizeLarge
            height: width
            fillMode: Image.PreserveAspectFit
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Sailvisor"
            font.pixelSize: Theme.fontSizeLarge
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: cover.running > 0 ? qsTr("%n running", "", cover.running) : qsTr("%1 VMs").arg(cover.total)
            color: cover.running > 0 ? "#4caf50" : Theme.secondaryColor
        }
    }
}
