import QtQuick 2.0
import Sailfish.Silica 1.0
import "util.js" as Util

Page {
    id: page

    property var backend
    property string message: ""

    function showMessage(text) {
        message = text
        messageTimer.restart()
    }

    function refresh() {
        if (!backend.ready) return
        backend.run("list_vms", [], function(vms) {
            if (vms.length !== vmModel.count) {
                vmModel.clear()
                for (var i = 0; i < vms.length; i++) vmModel.append(toRow(vms[i]))
            } else {
                for (var j = 0; j < vms.length; j++) vmModel.set(j, toRow(vms[j]))
            }
            loaded = true
        }, function(err) { showMessage(err) })
    }

    function toRow(v) {
        return { vmId: v.id, name: v.name, vmState: v.state, cpus: v.cpus, memoryMb: v.memory_mb,
                 guestReady: v.guest_ready, exitReason: v.exit_reason || "", uptime: v.uptime || 0 }
    }

    function openVm(vmId) {
        pageStack.push(Qt.resolvedUrl("VmPage.qml"), { backend: backend, vmId: vmId, owner: page })
    }

    function startVm(vmId) {
        backend.run("start_vm", [vmId], function() { refresh() }, function(err) { showMessage(err); refresh() })
    }

    function stopVm(vmId) {
        backend.run("stop_vm", [vmId], function() { refresh() }, function(err) { showMessage(err) })
    }

    property bool loaded: false

    ListModel { id: vmModel }

    Timer {
        id: messageTimer
        interval: 8000
        onTriggered: page.message = ""
    }

    Timer {
        interval: 2000
        repeat: true
        running: page.status === PageStatus.Active && Qt.application.active
        onTriggered: page.refresh()
    }

    Connections {
        target: backend
        onReadyChanged: page.refresh()
    }

    onStatusChanged: if (status === PageStatus.Active) refresh()
    Component.onCompleted: refresh()

    SilicaListView {
        id: list
        anchors.fill: parent
        model: vmModel

        header: Column {
            width: list.width
            PageHeader {
                title: "Sailvisor"
                description: qsTr("Virtual machines on GenieZone")
            }
            Label {
                visible: page.message.length > 0
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: page.message
                color: "#ff6e6e"
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
            }
            Item {
                visible: page.message.length > 0
                width: 1
                height: Theme.paddingMedium
            }
        }

        PullDownMenu {
            MenuItem {
                text: qsTr("Diagnostics")
                onClicked: pageStack.push(Qt.resolvedUrl("DiagnosticsPage.qml"), { backend: backend, owner: page })
            }
            MenuItem {
                text: qsTr("Import ISO (experimental)")
                onClicked: pageStack.push(Qt.resolvedUrl("ImportIsoDialog.qml"), { backend: backend, owner: page })
            }
            MenuItem {
                text: qsTr("New VM")
                onClicked: pageStack.push(Qt.resolvedUrl("VmDialog.qml"), { backend: backend, owner: page })
            }
            MenuItem {
                text: qsTr("New test VM")
                onClicked: backend.run("create_test_vm", ["heartbeat"], function(id) {
                    refresh()
                    openVm(id)
                }, function(err) { showMessage(err) })
            }
        }

        PushUpMenu {
            MenuItem {
                text: qsTr("App log")
                onClicked: pageStack.push(Qt.resolvedUrl("LogPage.qml"),
                                          { backend: backend, title: qsTr("App log"), fn: "app_log_tail", args: [65536] })
            }
        }

        ViewPlaceholder {
            enabled: page.loaded && vmModel.count === 0
            text: qsTr("No virtual machines yet")
            hintText: qsTr("Pull down and choose \"New test VM\" or run Diagnostics first")
        }

        delegate: ListItem {
            id: item
            contentHeight: Theme.itemSizeMedium

            menu: ContextMenu {
                MenuItem {
                    text: qsTr("Start")
                    visible: !Util.isActive(model.vmState)
                    onClicked: page.startVm(model.vmId)
                }
                MenuItem {
                    text: qsTr("Stop")
                    visible: Util.isActive(model.vmState)
                    onClicked: page.stopVm(model.vmId)
                }
                MenuItem {
                    text: qsTr("Force kill")
                    visible: Util.isActive(model.vmState) || model.vmState === "dead"
                    onClicked: backend.run("kill_vm", [model.vmId], function() { page.refresh() },
                                           function(err) { page.showMessage(err) })
                }
                MenuItem {
                    text: qsTr("Delete")
                    visible: !Util.isActive(model.vmState)
                    onClicked: {
                        var vmId = model.vmId
                        item.remorseAction(qsTr("Deleting"), function() {
                            backend.run("delete_vm", [vmId], function() { page.refresh() },
                                        function(err) { page.showMessage(err) })
                        })
                    }
                }
            }

            onClicked: page.openVm(model.vmId)

            Rectangle {
                id: dot
                x: Theme.horizontalPageMargin
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.paddingLarge
                height: width
                radius: width / 2
                color: Util.stateColor(model.vmState)
            }

            Column {
                anchors {
                    left: dot.right
                    leftMargin: Theme.paddingLarge
                    right: parent.right
                    rightMargin: Theme.horizontalPageMargin
                    verticalCenter: parent.verticalCenter
                }
                Label {
                    width: parent.width
                    text: model.name
                    truncationMode: TruncationMode.Fade
                    color: item.highlighted ? Theme.highlightColor : Theme.primaryColor
                }
                Label {
                    width: parent.width
                    truncationMode: TruncationMode.Fade
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: item.highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
                    text: {
                        var s = model.vmState
                        if (model.vmState === "running")
                            s += (model.guestReady ? qsTr(" (guest ready)") : "") + " · " + Util.duration(model.uptime)
                        else if (model.exitReason)
                            s += " · " + model.exitReason
                        return s + " · " + model.cpus + " vCPU · " + model.memoryMb + " MiB"
                    }
                }
            }
        }

        VerticalScrollDecorator {}
    }
}
