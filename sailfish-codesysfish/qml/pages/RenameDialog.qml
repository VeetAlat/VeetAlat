import QtQuick 2.0
import Sailfish.Silica 1.0

Dialog {
    id: dialog

    property string name

    allowedOrientations: Orientation.All
    canAccept: nameField.text.trim() !== ""
    onAccepted: name = nameField.text.trim()

    Column {
        width: parent.width

        DialogHeader { acceptText: "Rename" }

        TextField {
            id: nameField
            width: parent.width
            label: "Name"
            text: dialog.name
            focus: true
            EnterKey.iconSource: "image://theme/icon-m-enter-accept"
            EnterKey.onClicked: dialog.accept()
        }
    }
}
