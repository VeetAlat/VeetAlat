import QtQuick 2.0
import Sailfish.Silica 1.0
import "../js/st.js" as St

// The online view: the PLC's state and every variable of the running
// program, live. Tap a variable to write a value, a BOOL's switch to flip
// it, a function block, struct or array to open it. Start, stop, step one
// cycle, or reset to the initial values.
Page {
    id: page

    property Plc plc
    property var editorPage: null   // the code page this was run from, if any
    property var expanded: ({})

    readonly property alias rows: rowsModel

    allowedOrientations: Orientation.All

    function refresh() {
        if (!plc || !plc.runtime) {
            rowsModel.clear()
            return
        }
        var rows = plc.runtime.rows(expanded)
        var same = rows.length === rowsModel.count
        for (var i = 0; same && i < rows.length; i++) {
            if (rowsModel.get(i).path !== rows[i].path) same = false
        }
        if (!same) {
            rowsModel.clear()
            for (var j = 0; j < rows.length; j++) rowsModel.append(rows[j])
            return
        }
        for (var k = 0; k < rows.length; k++) {
            if (rowsModel.get(k).value !== rows[k].value) rowsModel.setProperty(k, "value", rows[k].value)
        }
    }

    function toggle(path) {
        var e = expanded
        e[path] = !e[path]
        expanded = e
        refresh()
    }

    // Writes a value: "" or why not.
    function write(path, text) {
        var why = plc.runtime.write(path, text)
        plc.revision++
        return why
    }

    // The code, at the line of the error.
    function showError() {
        if (!plc.error) return
        var line = plc.error.line
        if (editorPage && editorPage.projectId === plc.projectId) {
            pageStack.pop(editorPage)
            editorPage.goToLine(line, 1)
        } else {
            var p = pageStack.push(Qt.resolvedUrl("EditorPage.qml"), { plc: plc, projectId: plc.projectId })
            p.goToLine(line, 1)
        }
    }

    function cycleChoices() { return [10, 20, 50, 100, 200, 500, 1000] }

    Connections {
        target: page.plc
        onRevisionChanged: if (page.status !== PageStatus.Inactive) page.refresh()
    }
    onStatusChanged: if (status === PageStatus.Activating) refresh()
    Component.onCompleted: refresh()

    ListModel { id: rowsModel }

    SilicaListView {
        id: list
        anchors.fill: parent
        model: rowsModel

        PullDownMenu {
            MenuItem {
                text: "Reset to initial values"
                onClicked: page.plc.reset()
            }
            MenuItem {
                text: "Code"
                onClicked: {
                    if (page.editorPage && page.editorPage.projectId === page.plc.projectId) pageStack.pop(page.editorPage)
                    else pageStack.push(Qt.resolvedUrl("EditorPage.qml"), { plc: page.plc, projectId: page.plc.projectId })
                }
            }
        }

        header: Column {
            width: list.width
            spacing: Theme.paddingSmall

            PageHeader {
                title: page.plc.projectName
                description: page.plc.mainName + " · " + (page.plc.error ? "Error" : page.plc.running ? "Running" : "Stopped")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryHighlightColor
                text: "Cycle " + page.plc.cycles + " · PLC time " + St.formatTime(page.plc.plcTime)
            }

            // Why it stopped, when it did.
            BackgroundItem {
                visible: page.plc.error !== null
                width: parent.width
                height: visible ? errorLabel.height + 2 * Theme.paddingMedium : 0
                onClicked: page.showError()
                Label {
                    id: errorLabel
                    x: Theme.horizontalPageMargin
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 2 * x
                    wrapMode: Text.Wrap
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.errorColor
                    text: page.plc.error ? "Stopped in line " + page.plc.error.line + ": " + page.plc.error.message
                                           + ". Tap to see the code." : ""
                }
            }

            Row {
                x: Theme.horizontalPageMargin
                spacing: Theme.paddingMedium
                Button {
                    preferredWidth: Theme.buttonWidthExtraSmall
                    text: page.plc.running ? "Stop" : "Start"
                    color: page.plc.running ? Theme.primaryColor : Theme.highlightColor
                    onClicked: page.plc.running ? page.plc.stop() : page.plc.start()
                }
                Button {
                    preferredWidth: Theme.buttonWidthExtraSmall
                    text: "Step"
                    enabled: !page.plc.running
                    onClicked: page.plc.step()
                }
                Button {
                    preferredWidth: Theme.buttonWidthExtraSmall
                    text: "Reset"
                    onClicked: page.plc.reset()
                }
            }

            ComboBox {
                id: cycleBox
                width: parent.width
                label: "Cycle time"
                currentIndex: Math.max(0, page.cycleChoices().indexOf(page.plc.cycleMs))
                menu: ContextMenu {
                    Repeater {
                        model: page.cycleChoices()
                        MenuItem { text: modelData + " ms" }
                    }
                }
                onCurrentIndexChanged: page.plc.setCycleMs(page.cycleChoices()[currentIndex])
            }

            SectionHeader { text: "Variables" }
        }

        delegate: ListItem {
            id: row
            contentHeight: Theme.itemSizeSmall

            onClicked: {
                if (model.kind === "node") page.toggle(model.path)
                else if (model.kind === "bool" && model.writable) page.write(model.path, model.value === "TRUE" ? "FALSE" : "TRUE")
                else if (model.writable) {
                    pageStack.push(Qt.resolvedUrl("WriteDialog.qml"),
                                   { plc: page.plc, path: model.path, name: model.name, typeName: model.type, current: model.value })
                }
            }

            Label {
                id: arrow
                x: Theme.horizontalPageMargin + model.depth * Theme.paddingLarge * 1.5
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.paddingLarge * 1.5
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryHighlightColor
                text: model.kind === "node" ? (model.expanded ? "▾" : "▸") : ""
            }

            Column {
                anchors {
                    left: arrow.right
                    right: valueItem.left; rightMargin: Theme.paddingMedium
                    verticalCenter: parent.verticalCenter
                }
                Label {
                    width: parent.width
                    truncationMode: TruncationMode.Fade
                    font.pixelSize: Theme.fontSizeSmall
                    color: row.highlighted ? Theme.highlightColor : Theme.primaryColor
                    text: model.name
                }
                Label {
                    width: parent.width
                    truncationMode: TruncationMode.Fade
                    font.pixelSize: Theme.fontSizeTiny
                    color: Theme.secondaryColor
                    text: model.type + (model.section === "VAR_INPUT" ? " · input" : model.section === "VAR_OUTPUT" ? " · output" : "")
                }
            }

            Item {
                id: valueItem
                anchors {
                    right: parent.right; rightMargin: Theme.horizontalPageMargin
                    verticalCenter: parent.verticalCenter
                }
                width: model.kind === "bool" ? boolSwitch.width : Math.min(valueLabel.implicitWidth, row.width * 0.45)
                height: model.kind === "bool" ? boolSwitch.height : valueLabel.height

                Switch {
                    id: boolSwitch
                    visible: model.kind === "bool"
                    anchors.centerIn: parent
                    automaticCheck: false
                    enabled: model.writable
                    checked: model.value === "TRUE"
                    onClicked: page.write(model.path, checked ? "FALSE" : "TRUE")
                }
                Label {
                    id: valueLabel
                    visible: model.kind !== "bool"
                    anchors.right: parent.right
                    width: parent.width
                    horizontalAlignment: Text.AlignRight
                    truncationMode: TruncationMode.Fade
                    font.family: "DejaVu Sans Mono"
                    font.pixelSize: Theme.fontSizeSmall
                    color: model.writable ? Theme.highlightColor : Theme.secondaryHighlightColor
                    text: model.value
                }
            }
        }

        ViewPlaceholder {
            enabled: !page.plc.loaded
            text: "Nothing running"
            hintText: "Open a project and tap Run"
        }

        VerticalScrollDecorator { }
    }
}
