import QtQuick 2.0
import Sailfish.Silica 1.0
import "../js/store.js" as Store
import "../js/examples.js" as Examples

// The projects, newest first, with the running one on top. Pull down for
// a new project, the ST reference and About.
Page {
    id: page

    property Plc plc
    property var projects: []
    property int pendingOpen: -1   // a new project opens once its dialog is gone

    allowedOrientations: Orientation.All

    function refresh() { projects = Store.list() }

    function open(id) {
        return pageStack.push(Qt.resolvedUrl("EditorPage.qml"), { plc: page.plc, projectId: id })
    }

    // Makes a project from source (the template or an example): its id.
    function create(name, source, description) {
        var id = Store.create(Store.freeName(name), source, description || "")
        refresh()
        return id
    }

    function newProject() {
        var dialog = pageStack.push(Qt.resolvedUrl("NewProjectDialog.qml"))
        dialog.accepted.connect(function() {
            var ex = dialog.example >= 0 ? Examples.projects[dialog.example] : null
            page.pendingOpen = page.create(dialog.name, ex ? ex.source : Examples.TEMPLATE, ex ? ex.description : "")
        })
    }

    function openRunning() {
        return pageStack.push(Qt.resolvedUrl("RunPage.qml"), { plc: page.plc })
    }

    onStatusChanged: {
        if (status === PageStatus.Active) {
            refresh()
            if (pendingOpen >= 0) {
                var id = pendingOpen
                pendingOpen = -1
                open(id)
            }
        }
    }
    Component.onCompleted: refresh()

    SilicaListView {
        id: list
        anchors.fill: parent
        model: page.projects

        PullDownMenu {
            MenuItem {
                text: "About"
                onClicked: pageStack.push(Qt.resolvedUrl("AboutPage.qml"))
            }
            MenuItem {
                text: "ST reference"
                onClicked: pageStack.push(Qt.resolvedUrl("HelpPage.qml"))
            }
            MenuItem {
                text: "New project"
                onClicked: page.newProject()
            }
        }

        header: Column {
            width: list.width

            PageHeader {
                title: "CodeSysFish"
                description: "Structured Text, compiled and run"
            }

            // The PLC, when a project is loaded on it.
            BackgroundItem {
                id: running
                visible: page.plc !== null && page.plc.loaded
                width: parent.width
                height: visible ? runningColumn.height + 2 * Theme.paddingMedium : 0
                onClicked: page.openRunning()

                Rectangle {
                    anchors.fill: parent
                    color: Theme.rgba(Theme.highlightBackgroundColor, 0.12)
                }
                Rectangle {
                    id: lamp
                    x: Theme.horizontalPageMargin
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.paddingLarge
                    height: width
                    radius: width / 2
                    color: !page.plc ? "transparent" : page.plc.error ? Theme.errorColor
                         : page.plc.running ? "#4cd964" : Theme.secondaryColor
                }
                Column {
                    id: runningColumn
                    anchors {
                        left: lamp.right; leftMargin: Theme.paddingMedium
                        right: parent.right; rightMargin: Theme.horizontalPageMargin
                        verticalCenter: parent.verticalCenter
                    }
                    Label {
                        width: parent.width
                        truncationMode: TruncationMode.Fade
                        color: running.highlighted ? Theme.highlightColor : Theme.primaryColor
                        text: page.plc ? page.plc.projectName : ""
                    }
                    Label {
                        width: parent.width
                        truncationMode: TruncationMode.Fade
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: Theme.secondaryHighlightColor
                        text: !page.plc ? "" : page.plc.error ? "Stopped by an error in line " + page.plc.error.line
                            : (page.plc.running ? "Running" : "Stopped") + " · cycle " + page.plc.cycles + " · tap for the online view"
                    }
                }
            }
        }

        delegate: ListItem {
            id: item
            contentHeight: Math.max(Theme.itemSizeMedium, column.height + 2 * Theme.paddingMedium)

            readonly property bool isLoaded: page.plc !== null && page.plc.projectId === modelData.id

            onClicked: page.open(modelData.id)

            menu: ContextMenu {
                MenuItem {
                    text: "Rename"
                    onClicked: {
                        var id = modelData.id
                        var dialog = pageStack.push(Qt.resolvedUrl("RenameDialog.qml"), { name: modelData.name })
                        dialog.accepted.connect(function() {
                            Store.rename(id, dialog.name)
                            if (page.plc.projectId === id) page.plc.projectName = dialog.name
                            page.refresh()
                        })
                    }
                }
                MenuItem {
                    text: "Duplicate"
                    onClicked: {
                        var p = Store.get(modelData.id)
                        if (p) page.create(p.name + " copy", p.source, p.description)
                    }
                }
                MenuItem {
                    text: "Delete"
                    onClicked: {
                        var id = modelData.id
                        item.remorseDelete(function() {
                            if (page.plc.projectId === id) page.plc.unload()
                            Store.remove(id)
                            page.refresh()
                        })
                    }
                }
            }

            Column {
                id: column
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                anchors.verticalCenter: parent.verticalCenter

                Label {
                    width: parent.width
                    truncationMode: TruncationMode.Fade
                    color: item.highlighted ? Theme.highlightColor : Theme.primaryColor
                    text: (item.isLoaded ? "▶ " : "") + modelData.name
                }
                Label {
                    width: parent.width
                    visible: text !== ""
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: item.highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
                    text: modelData.description
                }
            }
        }

        ViewPlaceholder {
            enabled: list.count === 0
            text: "No projects"
            hintText: "Pull down to make one"
        }

        VerticalScrollDecorator { }
    }
}
