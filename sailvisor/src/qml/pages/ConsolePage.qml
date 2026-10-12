import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: page

    property var backend
    property string vmId
    property string text: ""
    property bool follow: true
    property string message: ""

    function refresh() {
        backend.run("console_tail", [vmId, 32768], function(t) {
            if (t === page.text) return
            var atBottom = flick.atYEnd || flick.contentHeight <= flick.height
            page.text = t
            if (page.follow && atBottom) scrollTimer.restart()
        })
    }

    function send(data) {
        backend.run("send_console", [vmId, data], function() {
            message = ""
            refreshSoon.restart()
        }, function(err) { message = err })
    }

    Timer {
        interval: 700
        repeat: true
        running: page.status === PageStatus.Active && Qt.application.active
        triggeredOnStart: true
        onTriggered: page.refresh()
    }
    Timer { id: refreshSoon; interval: 250; onTriggered: page.refresh() }
    Timer {
        id: scrollTimer
        interval: 30
        onTriggered: flick.contentY = Math.max(0, flick.contentHeight - flick.height)
    }

    SilicaFlickable {
        id: flick
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            bottom: inputArea.top
        }
        clip: true
        contentHeight: content.height

        PullDownMenu {
            MenuItem {
                text: page.follow ? qsTr("Stop auto-scroll") : qsTr("Auto-scroll")
                onClicked: page.follow = !page.follow
            }
            MenuItem {
                text: qsTr("Copy console to clipboard")
                onClicked: Clipboard.text = page.text
            }
            MenuItem {
                text: qsTr("Send Ctrl+C")
                onClicked: page.send("\u0003")
            }
        }

        Column {
            id: content
            width: parent.width
            PageHeader { title: qsTr("Console") ; description: vmId }
            Label {
                x: Theme.paddingMedium
                width: parent.width - 2 * x
                text: page.text.length ? page.text : qsTr("(no output yet)")
                textFormat: Text.PlainText
                wrapMode: Text.WrapAnywhere
                font.family: "monospace"
                font.pixelSize: Theme.fontSizeTiny
                color: "#c8e6c9"
            }
        }
        VerticalScrollDecorator {}
    }

    Column {
        id: inputArea
        anchors.bottom: parent.bottom
        width: parent.width

        Label {
            x: Theme.horizontalPageMargin
            width: parent.width - 2 * x
            visible: page.message.length > 0
            text: page.message
            color: "#ff6e6e"
            wrapMode: Text.Wrap
            font.pixelSize: Theme.fontSizeExtraSmall
        }

        TextField {
            id: input
            width: parent.width
            placeholderText: qsTr("Type a command for the guest")
            label: qsTr("Enter sends the line to the guest serial console")
            font.family: "monospace"
            inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
            EnterKey.iconSource: "image://theme/icon-m-enter-accept"
            EnterKey.onClicked: {
                page.send(input.text + "\n")
                input.text = ""
            }
        }
    }
}
