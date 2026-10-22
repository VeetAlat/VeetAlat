import QtQuick 2.0
import Sailfish.Silica 1.0
import "../js/examples.js" as Examples

// A new project: its name, and what it starts from.
Dialog {
    id: dialog

    property string name: ""
    property int example: -1   // -1: an empty PLC_PRG, else that example

    allowedOrientations: Orientation.All
    canAccept: nameField.text.trim() !== ""

    onAccepted: {
        name = nameField.text.trim()
        example = startFrom.currentIndex - 1
    }

    Column {
        width: parent.width
        spacing: Theme.paddingMedium

        DialogHeader { acceptText: "Create" }

        TextField {
            id: nameField
            width: parent.width
            label: "Name"
            placeholderText: "Project name"
            text: "My program"
            focus: true
            EnterKey.iconSource: "image://theme/icon-m-enter-accept"
            EnterKey.onClicked: dialog.accept()
        }

        ComboBox {
            id: startFrom
            width: parent.width
            label: "Start from"
            menu: ContextMenu {
                MenuItem { text: "An empty PLC_PRG" }
                Repeater {
                    model: Examples.projects
                    MenuItem { text: modelData.name }
                }
            }
        }
    }
}
