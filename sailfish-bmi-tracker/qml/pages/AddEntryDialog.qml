import QtQuick 2.0
import Sailfish.Silica 1.0
import "../components"
import "../js/bmi.js" as Bmi

Dialog {
    id: dialog

    property Store store
    property date selectedDate: new Date()

    readonly property bool pounds: store.weightUnit === "lb"
    readonly property real entered: Bmi.parseNumber(weightField.text)
    readonly property real weightKg: pounds ? Bmi.kgFromLb(entered) : entered
    readonly property bool valid: weightKg >= 20 && weightKg <= 400
    readonly property real previewBmi: valid ? Bmi.bmi(weightKg, store.heightCm) : NaN

    canAccept: valid

    onAccepted: store.addEntry(store.isoDate(selectedDate), weightKg)

    Column {
        width: parent.width

        DialogHeader {
            title: "Add weight"
            acceptText: "Save"
        }

        TextField {
            id: weightField
            width: parent.width
            focus: true
            label: dialog.pounds ? "Weight (lb)" : "Weight (kg)"
            placeholderText: label
            inputMethodHints: Qt.ImhFormattedNumbersOnly
            EnterKey.iconSource: "image://theme/icon-m-enter-accept"
            EnterKey.enabled: dialog.canAccept
            EnterKey.onClicked: dialog.accept()
        }

        ValueButton {
            label: "Date"
            value: Qt.formatDate(dialog.selectedDate, Qt.DefaultLocaleLongDate)
            onClicked: {
                var picker = pageStack.push("Sailfish.Silica.DatePickerDialog",
                                            { date: dialog.selectedDate })
                picker.accepted.connect(function() { dialog.selectedDate = picker.date })
            }
        }

        Item { width: 1; height: Theme.paddingLarge }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: dialog.valid
            font.pixelSize: Theme.fontSizeExtraLarge
            color: Theme.highlightColor
            text: "BMI " + Bmi.rounded(dialog.previewBmi).toFixed(1)
        }
        CategoryLabel {
            anchors.horizontalCenter: parent.horizontalCenter
            category: dialog.valid ? Bmi.category(dialog.previewBmi) : null
        }
    }
}
