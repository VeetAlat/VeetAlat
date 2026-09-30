import QtQuick 2.0
import Sailfish.Silica 1.0
import "../js/bmi.js" as Bmi

Dialog {
    id: dialog

    property Store store

    readonly property bool metricHeight: heightUnitBox.currentIndex === 0
    readonly property real heightCm: {
        if (metricHeight) return Bmi.parseNumber(cmField.text)
        var ft = Bmi.parseNumber(ftField.text)
        var inch = inField.text.trim() === "" ? 0 : Bmi.parseNumber(inField.text)
        return Bmi.cmFromFtIn(ft, inch)
    }
    readonly property bool heightValid: heightCm >= 50 && heightCm <= 272
    readonly property int age: parseInt(ageField.text, 10) || 0
    readonly property bool ageValid: ageField.text === "" || (age >= 2 && age <= 120)

    readonly property var genders: ["", "female", "male", "other"]

    canAccept: heightValid && ageValid

    // Show a height in both unit systems' fields.
    function fillHeight(cm) {
        if (!(cm > 0)) return
        cmField.text = String(Math.round(cm))
        var f = Bmi.ftInFromCm(cm)
        ftField.text = String(f.ft)
        inField.text = String(f.inch)
    }

    Component.onCompleted: {
        genderBox.currentIndex = Math.max(0, genders.indexOf(store.gender))
        ageField.text = store.age > 0 ? String(store.age) : ""
        weightUnitBox.currentIndex = store.weightUnit === "lb" ? 1 : 0
        heightUnitBox.currentIndex = store.heightUnit === "ftin" ? 1 : 0
        fillHeight(store.heightCm)
    }

    onAccepted: store.saveProfile({
        gender: genders[genderBox.currentIndex],
        age: age,
        heightCm: Math.round(heightCm * 10) / 10,
        weightUnit: weightUnitBox.currentIndex === 1 ? "lb" : "kg",
        heightUnit: metricHeight ? "cm" : "ftin"
    })

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        VerticalScrollDecorator { }

        Column {
            id: column
            width: parent.width

            DialogHeader {
                title: "Profile and units"
                acceptText: "Save"
            }

            SectionHeader { text: "About you" }

            ComboBox {
                id: genderBox
                label: "Gender"
                menu: ContextMenu {
                    MenuItem { text: "Not set" }
                    MenuItem { text: "Female" }
                    MenuItem { text: "Male" }
                    MenuItem { text: "Other" }
                }
            }

            TextField {
                id: ageField
                width: parent.width
                label: dialog.ageValid ? "Age (years)" : "Age must be 2–120"
                placeholderText: "Age (years)"
                inputMethodHints: Qt.ImhDigitsOnly
                validator: IntValidator { bottom: 0; top: 150 }
                EnterKey.iconSource: "image://theme/icon-m-enter-next"
                EnterKey.onClicked: (dialog.metricHeight ? cmField : ftField).focus = true
            }

            SectionHeader { text: "Height" }

            ComboBox {
                id: heightUnitBox
                label: "Height in"
                menu: ContextMenu {
                    MenuItem { text: "Centimetres" }
                    MenuItem { text: "Feet and inches" }
                }
            }

            TextField {
                id: cmField
                visible: dialog.metricHeight
                width: parent.width
                label: "Height (cm)"
                placeholderText: "Height (cm)"
                inputMethodHints: Qt.ImhFormattedNumbersOnly
                // Keep feet/inches in step, so switching units shows the same height.
                onTextChanged: if (activeFocus) {
                    var cm = Bmi.parseNumber(text)
                    if (cm > 0) {
                        var f = Bmi.ftInFromCm(cm)
                        ftField.text = String(f.ft)
                        inField.text = String(f.inch)
                    }
                }
                EnterKey.iconSource: "image://theme/icon-m-enter-accept"
                EnterKey.enabled: dialog.canAccept
                EnterKey.onClicked: dialog.accept()
            }

            Row {
                visible: !dialog.metricHeight
                width: parent.width
                TextField {
                    id: ftField
                    width: parent.width / 2
                    label: "Feet"
                    placeholderText: "Feet"
                    inputMethodHints: Qt.ImhDigitsOnly
                    onTextChanged: if (activeFocus && dialog.heightValid) cmField.text = String(Math.round(dialog.heightCm))
                    EnterKey.iconSource: "image://theme/icon-m-enter-next"
                    EnterKey.onClicked: inField.focus = true
                }
                TextField {
                    id: inField
                    width: parent.width / 2
                    label: "Inches"
                    placeholderText: "Inches"
                    inputMethodHints: Qt.ImhFormattedNumbersOnly
                    onTextChanged: if (activeFocus && dialog.heightValid) cmField.text = String(Math.round(dialog.heightCm))
                    EnterKey.iconSource: "image://theme/icon-m-enter-accept"
                    EnterKey.enabled: dialog.canAccept
                    EnterKey.onClicked: dialog.accept()
                }
            }

            SectionHeader { text: "Weight" }

            ComboBox {
                id: weightUnitBox
                label: "Weight in"
                menu: ContextMenu {
                    MenuItem { text: "Kilograms (kg)" }
                    MenuItem { text: "Pounds (lb)" }
                }
            }

            Item { width: 1; height: Theme.paddingLarge }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryHighlightColor
                text: "Adult BMI categories are the same for every gender. Your age "
                      + "decides whether they apply: under 20, BMI is judged against "
                      + "growth charts instead. Weights are stored in kilograms, so "
                      + "switching units never changes your history."
            }
        }
    }
}
