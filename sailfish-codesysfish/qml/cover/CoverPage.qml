import QtQuick 2.0
import Sailfish.Silica 1.0
import "../pages"

// The PLC at a glance: the project, whether it runs, its cycles, and a
// play/pause action.
CoverBackground {
    id: cover

    property Plc plc

    readonly property string statusText: !plc || !plc.loaded ? "Nothing running"
                                  : plc.error ? "Error in line " + plc.error.line
                                  : plc.running ? "Running" : "Stopped"

    Column {
        x: Theme.paddingLarge
        y: Theme.paddingLarge
        width: parent.width - 2 * x
        spacing: Theme.paddingSmall

        Label {
            width: parent.width
            truncationMode: TruncationMode.Fade
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.highlightColor
            text: "CodeSysFish"
        }
        Label {
            width: parent.width
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            text: cover.plc && cover.plc.loaded ? cover.plc.projectName : ""
        }
        Row {
            spacing: Theme.paddingSmall
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.paddingMedium
                height: width
                radius: width / 2
                visible: cover.plc && cover.plc.loaded
                color: !cover.plc ? "transparent" : cover.plc.error ? Theme.errorColor
                     : cover.plc.running ? "#4cd964" : Theme.secondaryColor
            }
            Label {
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                text: cover.statusText
            }
        }
        Label {
            width: parent.width
            visible: cover.plc && cover.plc.loaded
            font.pixelSize: Theme.fontSizeExtraSmall
            color: Theme.secondaryColor
            text: cover.plc ? "Cycle " + cover.plc.cycles : ""
        }
    }

    CoverActionList {
        enabled: cover.plc !== null && cover.plc.loaded
        CoverAction {
            iconSource: cover.plc && cover.plc.running ? "image://theme/icon-cover-pause" : "image://theme/icon-cover-play"
            onTriggered: cover.plc.running ? cover.plc.stop() : cover.plc.start()
        }
    }
}
