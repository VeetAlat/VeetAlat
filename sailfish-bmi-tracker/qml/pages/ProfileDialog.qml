import QtQuick 2.0
import Sailfish.Silica 1.0
import "../components"
import "../js/bmi.js" as Bmi

// Profile and units, as three numbered steps with tap-to-choose buttons.
// Save with the button at the bottom (or "Save" at the top).
Dialog {
    id: dialog

    property Store store

    // Current choices; filled from the store when the page opens.
    property string gender: ""
    property string heightUnit: "cm"
    property string weightUnit: "kg"
    property alias ageText: ageField.text
    property alias cmText: cmField.text
    property alias ftText: ftField.text
    property alias inText: inField.text

    readonly property bool metricHeight: heightUnit === "cm"
    readonly property real heightCm: {
        if (metricHeight) return Bmi.parseNumber(cmText)
        var ft = Bmi.parseNumber(ftText)
        var inch = inText.trim() === "" ? 0 : Bmi.parseNumber(inText)
        return Bmi.cmFromFtIn(ft, inch)
    }
    readonly property bool heightValid: heightCm >= 50 && heightCm <= 272
    readonly property int age: parseInt(ageText, 10) || 0
    readonly property bool ageValid: ageText === "" || (age >= 2 && age <= 120)

    canAccept: heightValid && ageValid

    // Put a height into both the cm and the feet/inches fields.
    function fillHeight(cm) {
        if (!(cm > 0)) return
        cmText = String(Math.round(cm))
        var f = Bmi.ftInFromCm(cm)
        ftText = String(f.ft)
        inText = String(f.inch)
    }

    function loadFromStore() {
        gender = store.gender
        heightUnit = store.heightUnit
        weightUnit = store.weightUnit
        ageText = store.age > 0 ? String(store.age) : ""
        fillHeight(store.heightCm)
    }

    Component.onCompleted: loadFromStore()

    onAccepted: store.saveProfile({
        gender: gender,
        age: age,
        heightCm: Math.round(heightCm * 10) / 10,
        weightUnit: weightUnit,
        heightUnit: heightUnit
    })

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        VerticalScrollDecorator { }

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingMedium

            DialogHeader {
                title: "Your profile"
                acceptText: "Save"
            }

            Instruction {
                text: "Your height is needed to work out your BMI. Age and gender "
                      + "are optional. Fill in the three steps and tap Save."
            }

            // Step 1
            SectionHeader { text: "1 · About you" }

            Label {
                x: Theme.horizontalPageMargin
                color: Theme.highlightColor
                text: "Gender (optional)"
            }
            ChoiceButtons {
                options: [{ value: "female", text: "Female" },
                          { value: "male", text: "Male" },
                          { value: "other", text: "Other" }]
                value: dialog.gender
                // Tapping the chosen one again clears it.
                onPicked: dialog.gender = (dialog.gender === newValue ? "" : newValue)
            }

            TextField {
                id: ageField
                width: parent.width
                label: dialog.ageValid ? "Age in years (optional)" : "Age must be between 2 and 120"
                placeholderText: "Age in years (optional)"
                inputMethodHints: Qt.ImhDigitsOnly
                validator: IntValidator { bottom: 0; top: 150 }
                EnterKey.iconSource: "image://theme/icon-m-enter-next"
                EnterKey.onClicked: (dialog.metricHeight ? cmField : ftField).forceActiveFocus()
            }

            // Step 2
            SectionHeader { text: "2 · Your height" }

            Instruction { text: "Choose how you want to enter it:" }

            ChoiceButtons {
                options: [{ value: "cm", text: "Centimetres" },
                          { value: "ftin", text: "Feet + inches" }]
                value: dialog.heightUnit
                onPicked: {
                    // Keep a typed height when switching.
                    var cm = dialog.heightCm
                    dialog.heightUnit = newValue
                    if (cm >= 50 && cm <= 272) dialog.fillHeight(cm)
                }
            }

            TextField {
                id: cmField
                visible: dialog.metricHeight
                width: parent.width
                label: "Height in centimetres, e.g. 175"
                placeholderText: "Height in cm"
                inputMethodHints: Qt.ImhFormattedNumbersOnly
                EnterKey.iconSource: "image://theme/icon-m-enter-close"
                EnterKey.onClicked: focus = false
            }

            Row {
                visible: !dialog.metricHeight
                width: parent.width
                TextField {
                    id: ftField
                    width: parent.width / 2
                    label: "Feet, e.g. 5"
                    placeholderText: "Feet"
                    inputMethodHints: Qt.ImhDigitsOnly
                    EnterKey.iconSource: "image://theme/icon-m-enter-next"
                    EnterKey.onClicked: inField.forceActiveFocus()
                }
                TextField {
                    id: inField
                    width: parent.width / 2
                    label: "Inches, e.g. 9"
                    placeholderText: "Inches"
                    inputMethodHints: Qt.ImhFormattedNumbersOnly
                    EnterKey.iconSource: "image://theme/icon-m-enter-close"
                    EnterKey.onClicked: focus = false
                }
            }

            // Step 3
            SectionHeader { text: "3 · Weigh yourself in" }

            ChoiceButtons {
                options: [{ value: "kg", text: "Kilograms" },
                          { value: "lb", text: "Pounds" }]
                value: dialog.weightUnit
                onPicked: dialog.weightUnit = newValue
            }

            Instruction {
                text: "You can switch units any time. Your weights are kept in "
                      + "kilograms, so switching never changes your history."
            }

            Item { width: 1; height: Theme.paddingLarge }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: !dialog.canAccept
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
                color: Theme.errorColor
                text: !dialog.heightValid ? "Enter your height in step 2 to save."
                                          : "Check your age in step 1."
            }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                preferredWidth: Theme.buttonWidthLarge
                enabled: dialog.canAccept
                text: "Save"
                onClicked: dialog.accept()
            }

            Instruction {
                text: "Adult BMI categories are the same for every gender. If you're "
                      + "under 20, BMI is judged against growth charts instead, and the "
                      + "app will remind you of that."
            }
        }
    }
}
