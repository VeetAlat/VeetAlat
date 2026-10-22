import QtQuick 2.0
import Sailfish.Silica 1.0
import "../js/reference.js" as Reference

// The ST reference: what CodeSysFish understands, with an example for
// each part. Tap an example to copy it.
Page {
    id: page

    allowedOrientations: Orientation.All

    SilicaListView {
        id: list
        anchors.fill: parent
        model: Reference.sections

        header: PageHeader {
            title: "ST reference"
            description: "Structured Text in CodeSysFish"
        }

        delegate: Column {
            width: list.width
            spacing: Theme.paddingSmall

            SectionHeader { text: modelData.title }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.highlightColor
                text: modelData.text
            }

            BackgroundItem {
                visible: modelData.code !== ""
                width: parent.width
                height: visible ? code.height + 2 * Theme.paddingMedium : 0
                onClicked: {
                    Clipboard.text = modelData.code
                    copied.text = "Copied"
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.horizontalPageMargin - Theme.paddingSmall
                    anchors.rightMargin: anchors.leftMargin
                    color: Theme.rgba(Theme.highlightBackgroundColor, 0.1)
                    radius: Theme.paddingSmall
                }
                Label {
                    id: code
                    x: Theme.horizontalPageMargin
                    y: Theme.paddingMedium
                    width: parent.width - 2 * x
                    wrapMode: Text.WrapAnywhere
                    textFormat: Text.PlainText
                    font.family: "DejaVu Sans Mono"
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: Theme.primaryColor
                    text: modelData.code
                }
                Label {
                    id: copied
                    anchors { right: parent.right; rightMargin: Theme.horizontalPageMargin; top: parent.top; topMargin: Theme.paddingSmall }
                    font.pixelSize: Theme.fontSizeTiny
                    color: Theme.secondaryHighlightColor
                    text: "Tap to copy"
                }
            }

            Item { width: 1; height: Theme.paddingMedium }
        }

        VerticalScrollDecorator { }
    }
}
