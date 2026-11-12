import QtQuick 2.0
import Sailfish.Silica 1.0
import VeetPatched 1.0

// What VeetPatched did: the root helper's log and the app's, merged,
// newest first. Errors are red, warnings highlighted. "Problems only"
// leaves out the rest; Copy puts the whole log on the clipboard.
Page {
    id: page

    property Patcher patcher
    property bool problemsOnly: false

    readonly property var shown: {
        var out = []
        var all = patcher ? patcher.logEntries : []
        for (var i = all.length - 1; i >= 0; i--) {
            if (!problemsOnly || all[i].level !== "INFO") out.push(all[i])
        }
        return out
    }
    readonly property int problemCount: {
        var n = 0
        var all = patcher ? patcher.logEntries : []
        for (var i = 0; i < all.length; i++) if (all[i].level !== "INFO") n++
        return n
    }

    allowedOrientations: Orientation.All

    Component.onCompleted: patcher.reloadLog()

    SilicaListView {
        id: list
        anchors.fill: parent
        model: page.shown

        PullDownMenu {
            MenuItem {
                text: "Copy log"
                onClicked: Clipboard.text = page.patcher.log
            }
            MenuItem {
                text: page.problemsOnly ? "Show everything" : "Problems only"
                onClicked: page.problemsOnly = !page.problemsOnly
            }
        }

        header: Column {
            width: list.width

            PageHeader {
                title: "Log"
                description: (page.problemsOnly ? "Problems only" : "Everything, newest first")
                             + " · " + (page.problemCount === 1 ? "1 problem" : page.problemCount + " problems")
            }
        }

        delegate: Item {
            width: list.width
            height: entryColumn.height + Theme.paddingMedium

            Rectangle {
                width: Theme.paddingSmall / 2
                height: parent.height - Theme.paddingSmall
                x: Theme.horizontalPageMargin - Theme.paddingMedium
                color: modelData.level === "ERROR" ? Theme.errorColor
                     : modelData.level === "WARN" ? Theme.highlightColor : "transparent"
            }

            Column {
                id: entryColumn
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x

                Label {
                    width: parent.width
                    font.pixelSize: Theme.fontSizeTiny
                    color: modelData.level === "ERROR" ? Theme.errorColor
                         : modelData.level === "WARN" ? Theme.highlightColor : Theme.secondaryColor
                    text: modelData.time + "  " + modelData.level + "  "
                          + (modelData.source === "helper" ? "helper (root)" : "app")
                }
                Label {
                    width: parent.width
                    wrapMode: Text.WrapAnywhere
                    textFormat: Text.PlainText
                    font.family: "DejaVu Sans Mono"
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: modelData.level === "INFO" ? Theme.primaryColor : Theme.highlightColor
                    text: modelData.text
                }
            }
        }

        ViewPlaceholder {
            enabled: list.count === 0
            text: page.problemsOnly ? "No problems" : "Nothing logged yet"
        }

        VerticalScrollDecorator { }
    }
}
