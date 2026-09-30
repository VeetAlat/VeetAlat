import QtQuick 2.0
import Sailfish.Silica 1.0
import "../components"
import "../js/bmi.js" as Bmi

Dialog {
    id: dialog

    property Store store
    property date selectedDate: new Date()
    property string unit: store ? store.weightUnit : "kg"
    property alias weightText: weightField.text

    readonly property bool pounds: unit === "lb"
    readonly property real entered: Bmi.parseNumber(weightText)
    readonly property real weightKg: pounds ? Bmi.kgFromLb(entered) : entered
    readonly property bool valid: weightKg >= 20 && weightKg <= 400
    readonly property real previewBmi: valid && store ? Bmi.bmi(weightKg, store.heightCm) : NaN

    canAccept: valid

    onAccepted: store.addEntry(store.isoDate(selectedDate), weightKg)

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingMedium

            DialogHeader {
                title: "Update weight"
                acceptText: "Save"
            }

            Instruction {
                text: "Type what your scale shows and tap Save at the top right. Change the date if "
                      + "you weighed yourself on another day."
            }

            ChoiceButtons {
                options: [{ value: "kg", text: "kg" }, { value: "lb", text: "lb" }]
                value: dialog.unit
                onPicked: {
                    // Convert a typed weight when switching units.
                    var kg = dialog.weightKg
                    dialog.unit = newValue
                    if (kg > 0) {
                        dialog.weightText = (newValue === "lb" ? Bmi.lbFromKg(kg) : kg).toFixed(1)
                    }
                }
            }

            TextField {
                id: weightField
                width: parent.width
                focus: true
                label: dialog.pounds ? "Weight in pounds, e.g. 165.5" : "Weight in kilograms, e.g. 72.5"
                placeholderText: dialog.pounds ? "Weight in lb" : "Weight in kg"
                inputMethodHints: Qt.ImhFormattedNumbersOnly
                EnterKey.iconSource: "image://theme/icon-m-enter-accept"
                EnterKey.enabled: dialog.canAccept
                EnterKey.onClicked: dialog.accept()
            }

            ValueButton {
                label: "Date"
                value: Qt.formatDate(dialog.selectedDate, Qt.DefaultLocaleLongDate)
                description: "Tap to change"
                onClicked: {
                    var picker = pageStack.push("Sailfish.Silica.DatePickerDialog",
                                                { date: dialog.selectedDate })
                    picker.accepted.connect(function() { dialog.selectedDate = picker.date })
                }
            }

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: dialog.valid
                font.pixelSize: Theme.fontSizeExtraLarge
                color: Theme.highlightColor
                text: "BMI " + Bmi.formatBmi(dialog.previewBmi)
            }
            CategoryLabel {
                anchors.horizontalCenter: parent.horizontalCenter
                category: dialog.valid ? Bmi.category(dialog.previewBmi) : null
            }
        }
    }
}
