import QtQuick 2.0
import Sailfish.Silica 1.0

// A row of buttons where exactly one is picked, like radio buttons.
// Tapping one selects it; the selected one is filled and outlined.
//
//   ChoiceButtons {
//       options: [{ value: "kg", text: "Kilograms" }, { value: "lb", text: "Pounds" }]
//       value: "kg"
//       onPicked: value = newValue
//   }
Item {
    id: choices

    property var options: []
    property string value
    signal picked(string newValue)

    width: parent ? parent.width : 0
    height: Theme.itemSizeSmall

    Row {
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        height: parent.height
        spacing: Theme.paddingMedium

        Repeater {
            model: choices.options
            delegate: MouseArea {
                id: button
                readonly property bool selected: choices.value === modelData.value
                width: (parent.width - (choices.options.length - 1) * parent.spacing) / choices.options.length
                height: parent.height
                onClicked: choices.picked(modelData.value)

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.paddingSmall
                    color: button.selected || button.pressed
                           ? Theme.rgba(Theme.highlightBackgroundColor, Theme.highlightBackgroundOpacity)
                           : Theme.rgba(Theme.primaryColor, 0.08)
                    border.width: button.selected ? 2 : 0
                    border.color: Theme.highlightColor
                }
                Label {
                    anchors.centerIn: parent
                    width: parent.width - 2 * Theme.paddingSmall
                    horizontalAlignment: Text.AlignHCenter
                    truncationMode: TruncationMode.Fade
                    color: button.selected || button.pressed ? Theme.highlightColor : Theme.primaryColor
                    font.bold: button.selected
                    text: modelData.text
                }
            }
        }
    }
}
