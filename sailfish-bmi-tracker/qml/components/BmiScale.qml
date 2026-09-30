import QtQuick 2.0
import Sailfish.Silica 1.0
import "../js/bmi.js" as Bmi

// Horizontal BMI scale from 15 to 40 in the four category colours, with a
// marker at the current value. Each segment is named above and the
// boundaries (18.5, 25, 30) are labelled below.
Item {
    id: bmiScale

    property real value: NaN

    readonly property real gap: 2 // surface gap between segments
    readonly property real barHeight: Theme.paddingMedium * 1.5

    implicitHeight: names.height + barHeight + ticks.height + 2 * Theme.paddingSmall

    function xFor(bmi) { return Bmi.scalePosition(bmi) * width }

    // Segment names
    Item {
        id: names
        width: parent.width
        height: Theme.fontSizeExtraSmall * 1.4
        Repeater {
            model: Bmi.categories
            delegate: Label {
                readonly property real from: bmiScale.xFor(Math.max(modelData.from, Bmi.SCALE_MIN))
                readonly property real to: bmiScale.xFor(Math.min(modelData.to, Bmi.SCALE_MAX))
                x: from
                width: to - from
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                truncationMode: TruncationMode.Fade
                text: modelData.shortName
            }
        }
    }

    // Coloured segments
    Item {
        id: bar
        anchors.top: names.bottom
        anchors.topMargin: Theme.paddingSmall
        width: parent.width
        height: bmiScale.barHeight
        Repeater {
            model: Bmi.categories
            delegate: Rectangle {
                readonly property real from: bmiScale.xFor(Math.max(modelData.from, Bmi.SCALE_MIN))
                readonly property real to: bmiScale.xFor(Math.min(modelData.to, Bmi.SCALE_MAX))
                x: from + (index > 0 ? bmiScale.gap / 2 : 0)
                width: to - from - (index > 0 ? bmiScale.gap / 2 : 0)
                             - (index < Bmi.categories.length - 1 ? bmiScale.gap / 2 : 0)
                height: parent.height
                radius: 4
                color: modelData.color
            }
        }
    }

    // Boundary labels
    Item {
        id: ticks
        anchors.top: bar.bottom
        anchors.topMargin: Theme.paddingSmall
        width: parent.width
        height: Theme.fontSizeExtraSmall * 1.4
        Repeater {
            model: [18.5, 25, 30]
            delegate: Label {
                x: bmiScale.xFor(modelData) - width / 2
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                text: modelData.toFixed(modelData % 1 ? 1 : 0)
            }
        }
    }

    // Marker: a bar across the scale with a 2px ring so it stands out on
    // every segment colour.
    Rectangle {
        visible: !isNaN(bmiScale.value)
        x: bmiScale.xFor(bmiScale.value) - width / 2
        y: bar.y - Theme.paddingSmall
        width: Theme.paddingSmall + 2 * border.width
        height: bar.height + 2 * Theme.paddingSmall
        radius: width / 2
        color: Theme.primaryColor
        border.width: 2
        border.color: Theme.highlightDimmerColor
    }
}
