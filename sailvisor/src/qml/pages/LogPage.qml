import QtQuick 2.0
import Sailfish.Silica 1.0

// Generic log viewer: shows the result of a bridge function returning text.
Page {
    id: page

    property var backend
    property string title
    property string fn
    property var args: []
    property string text: ""
    property bool autoRefresh: true
    property bool firstLoad: true

    function refresh() {
        backend.run(fn, args, function(t) {
            if (t === page.text) return
            var atBottom = flick.atYEnd || page.firstLoad
            page.text = t
            page.firstLoad = false
            if (atBottom) scrollTimer.restart()
        }, function(err) { page.text = qsTr("Error: %1").arg(err) })
    }

    Timer {
        interval: 2000
        repeat: true
        running: page.autoRefresh && page.status === PageStatus.Active && Qt.application.active
        triggeredOnStart: true
        onTriggered: page.refresh()
    }
    Timer {
        id: scrollTimer
        interval: 30
        onTriggered: flick.contentY = Math.max(0, flick.contentHeight - flick.height)
    }

    SilicaFlickable {
        id: flick
        anchors.fill: parent
        contentHeight: content.height + Theme.paddingLarge

        PullDownMenu {
            MenuItem {
                text: page.autoRefresh ? qsTr("Pause auto-refresh") : qsTr("Resume auto-refresh")
                onClicked: page.autoRefresh = !page.autoRefresh
            }
            MenuItem {
                text: qsTr("Copy to clipboard")
                onClicked: Clipboard.text = page.text
            }
            MenuItem {
                text: qsTr("Refresh")
                onClicked: page.refresh()
            }
        }

        Column {
            id: content
            width: parent.width
            PageHeader { title: page.title }
            Label {
                x: Theme.paddingMedium
                width: parent.width - 2 * x
                text: page.text.length ? page.text : qsTr("(empty)")
                textFormat: Text.PlainText
                wrapMode: Text.WrapAnywhere
                font.family: "monospace"
                font.pixelSize: Theme.fontSizeTiny
                color: Theme.primaryColor
            }
        }
        VerticalScrollDecorator {}
    }
}
