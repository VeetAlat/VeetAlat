import QtQuick 2.0
import Sailfish.Silica 1.0

// Writes one value to a variable of the running program, like CODESYS's
// "Write value". It's checked as it's typed.
Dialog {
    id: dialog

    property Plc plc
    property string path
    property string name
    property string typeName
    property string current

    readonly property string problem: plc && plc.runtime ? plc.runtime.check(path, field.text) : "The PLC isn't loaded"
    readonly property bool numeric: /INT|BYTE|WORD|REAL|TIME/.test(typeName) && typeName.indexOf("STRING") < 0

    allowedOrientations: Orientation.All
    canAccept: problem === ""

    onAccepted: {
        plc.runtime.write(path, field.text)
        plc.revision++
    }

    Column {
        width: parent.width
        spacing: Theme.paddingMedium

        DialogHeader {
            acceptText: "Write"
            title: dialog.name
        }

        Label {
            x: Theme.horizontalPageMargin
            width: parent.width - 2 * x
            wrapMode: Text.Wrap
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.secondaryHighlightColor
            text: dialog.path + " : " + dialog.typeName + "\nNow " + dialog.current
        }

        TextField {
            id: field
            width: parent.width
            label: dialog.problem === "" ? "New value" : dialog.problem
            text: dialog.current
            focus: true
            font.family: "DejaVu Sans Mono"
            inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                              | (dialog.numeric && dialog.typeName !== "TIME" ? Qt.ImhPreferNumbers : 0)
            errorHighlight: dialog.problem !== ""
            EnterKey.enabled: dialog.canAccept
            EnterKey.iconSource: "image://theme/icon-m-enter-accept"
            EnterKey.onClicked: dialog.accept()
            Component.onCompleted: selectAll()
        }

        Label {
            x: Theme.horizontalPageMargin
            width: parent.width - 2 * x
            wrapMode: Text.Wrap
            font.pixelSize: Theme.fontSizeExtraSmall
            color: Theme.secondaryColor
            text: dialog.typeName === "TIME" ? "Like T#1s500ms, or milliseconds"
                : /^STRING/.test(dialog.typeName) ? "Text, with or without 'quotes'"
                : /INT|BYTE|WORD/.test(dialog.typeName) ? "A whole number; 16#FF and 2#1010 work too"
                : /REAL/.test(dialog.typeName) ? "A number, like 1.5 or 2.5E3"
                : ""
        }
    }
}
