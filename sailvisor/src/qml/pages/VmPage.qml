import QtQuick 2.0
import Sailfish.Silica 1.0
import "util.js" as Util

Page {
    id: page

    property var backend
    property var owner
    property string vmId
    property var cfg: ({})
    property var st: ({})
    property var problems: []
    property var command: []
    property string consoleText: ""
    property string message: ""
    property bool busy: false
    readonly property bool active: Util.isActive(st.state)

    function showMessage(text) {
        message = text
    }

    function refresh() {
        backend.run("get_vm", [vmId], function(r) {
            cfg = r.config
            st = r.status
            problems = r.problems
            command = r.command
        }, function(err) { showMessage(err) })
        backend.run("console_tail", [vmId, 3000], function(text) {
            var lines = text.split("\n")
            consoleText = lines.slice(Math.max(0, lines.length - 14)).join("\n")
        })
    }

    function action(fn, okText) {
        busy = true
        message = ""
        backend.run(fn, [vmId], function() {
            busy = false
            if (okText) showMessage(okText)
            refresh()
        }, function(err) {
            busy = false
            showMessage(err)
            refresh()
        })
    }

    function openLog(title, fn, args) {
        pageStack.push(Qt.resolvedUrl("LogPage.qml"), { backend: backend, title: title, fn: fn, args: args })
    }

    Timer {
        interval: page.active ? 1000 : 3000
        repeat: true
        running: page.status === PageStatus.Active && Qt.application.active
        onTriggered: page.refresh()
    }

    onStatusChanged: if (status === PageStatus.Active) refresh()

    RemorsePopup { id: remorse }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        PullDownMenu {
            MenuItem {
                text: qsTr("Delete")
                enabled: !page.active
                onClicked: remorse.execute(qsTr("Deleting VM"), function() {
                    backend.run("delete_vm", [vmId], function() {
                        if (owner) owner.refresh()
                        pageStack.pop()
                    }, function(err) { showMessage(err) })
                })
            }
            MenuItem {
                text: qsTr("Copy crosvm command")
                onClicked: {
                    Clipboard.text = command.join(" ")
                    showMessage(qsTr("crosvm command copied to clipboard"))
                }
            }
            MenuItem {
                text: qsTr("Edit")
                enabled: !page.active
                onClicked: pageStack.push(Qt.resolvedUrl("VmDialog.qml"),
                                          { backend: backend, owner: page, vmId: vmId, initial: cfg })
            }
        }

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingMedium

            PageHeader {
                title: cfg.name || vmId
                description: vmId
            }

            Row {
                x: Theme.horizontalPageMargin
                spacing: Theme.paddingMedium
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.paddingLarge
                    height: width
                    radius: width / 2
                    color: Util.stateColor(st.state)
                }
                Label {
                    text: (st.state || "stopped").toUpperCase()
                    color: Util.stateColor(st.state)
                    font.pixelSize: Theme.fontSizeLarge
                }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: page.active
                    text: Util.duration(st.uptime) + (st.guest_ready ? qsTr(" · guest ready") : "")
                    color: Theme.secondaryColor
                }
                BusyIndicator {
                    anchors.verticalCenter: parent.verticalCenter
                    size: BusyIndicatorSize.Small
                    running: page.busy || st.state === "starting" || st.state === "stopping"
                }
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: text.length > 0
                text: !page.active && st.exit_reason ? qsTr("Last exit: %1 (code %2)").arg(st.exit_reason).arg(st.exit_code) : ""
                color: st.state === "stopped" ? Theme.secondaryColor : "#ff6e6e"
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: page.message.length > 0
                text: page.message
                color: "#ff6e6e"
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
            }

            ButtonLayout {
                Button {
                    text: qsTr("Start")
                    enabled: !page.active && !page.busy
                    onClicked: page.action("start_vm")
                }
                Button {
                    text: qsTr("Stop")
                    enabled: page.active && st.state !== "stopping" && !page.busy
                    onClicked: page.action("stop_vm", qsTr("Stop requested, waiting for crosvm to exit"))
                }
                Button {
                    text: qsTr("Force kill")
                    enabled: (page.active || st.state === "dead") && !page.busy
                    onClicked: page.action("kill_vm")
                }
            }

            SectionHeader { text: qsTr("Console") }

            BackgroundItem {
                width: parent.width
                height: consoleLabel.height + 2 * Theme.paddingMedium
                onClicked: pageStack.push(Qt.resolvedUrl("ConsolePage.qml"), { backend: backend, vmId: vmId })

                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.horizontalPageMargin
                    anchors.rightMargin: Theme.horizontalPageMargin
                    color: "#a0000000"
                    radius: Theme.paddingSmall
                }
                Label {
                    id: consoleLabel
                    x: Theme.horizontalPageMargin + Theme.paddingMedium
                    y: Theme.paddingMedium
                    width: parent.width - 2 * x
                    text: page.consoleText.length ? page.consoleText : qsTr("(no console output yet - tap to open the console)")
                    textFormat: Text.PlainText
                    font.family: "monospace"
                    font.pixelSize: Theme.fontSizeTiny
                    wrapMode: Text.WrapAnywhere
                    color: page.consoleText.length ? "#c8e6c9" : Theme.secondaryColor
                }
            }

            ButtonLayout {
                Button {
                    text: qsTr("Console")
                    onClicked: pageStack.push(Qt.resolvedUrl("ConsolePage.qml"), { backend: backend, vmId: vmId })
                }
                Button {
                    text: qsTr("VM log")
                    onClicked: page.openLog(qsTr("VM log"), "log_tail", [vmId, "vm.log", 65536])
                }
                Button {
                    text: qsTr("Previous run")
                    onClicked: page.openLog(qsTr("Previous run log"), "log_tail", [vmId, "vm.log.1", 65536])
                }
            }

            SectionHeader {
                text: qsTr("Problems")
                visible: problems.length > 0
            }
            Repeater {
                model: problems
                Label {
                    x: Theme.horizontalPageMargin
                    width: column.width - 2 * Theme.horizontalPageMargin
                    text: "✖ " + modelData
                    color: "#ff6e6e"
                    wrapMode: Text.Wrap
                    font.pixelSize: Theme.fontSizeSmall
                }
            }

            SectionHeader {
                text: qsTr("Last errors from crosvm")
                visible: !!st.errors && st.errors.length > 0
            }
            Repeater {
                model: st.errors || []
                Label {
                    x: Theme.horizontalPageMargin
                    width: column.width - 2 * Theme.horizontalPageMargin
                    text: modelData
                    color: "#ffab91"
                    wrapMode: Text.WrapAnywhere
                    font.family: "monospace"
                    font.pixelSize: Theme.fontSizeTiny
                }
            }

            SectionHeader { text: qsTr("Runtime") }
            DetailItem { label: qsTr("Supervisor PID"); value: st.supervisor_pid || "-" }
            DetailItem { label: qsTr("crosvm PID"); value: st.crosvm_pid || "-" }
            DetailItem { label: qsTr("Console connected"); value: Util.since(st, "console_connected_at") }
            DetailItem { label: qsTr("First guest output"); value: Util.since(st, "first_output_at") }
            DetailItem { label: qsTr("Guest ready"); value: st.guest_ready ? qsTr("yes") : qsTr("no") }
            DetailItem { label: qsTr("Last runtime"); value: st.runtime !== undefined ? Util.duration(st.runtime) : "-" }
            DetailItem { label: qsTr("Note"); value: st.note || "-"; visible: !!st.note }

            SectionHeader { text: qsTr("Configuration") }
            DetailItem { label: qsTr("vCPUs"); value: cfg.cpus || "-" }
            DetailItem { label: qsTr("Memory"); value: (cfg.memory_mb || "-") + " MiB" }
            DetailItem { label: qsTr("Kernel"); value: Util.basename(cfg.kernel) || "-" }
            DetailItem { label: qsTr("Initrd"); value: Util.basename(cfg.initrd) || "-" }
            DetailItem { label: qsTr("ISO"); value: Util.basename(cfg.iso) || "-"; visible: !!cfg.iso }
            DetailItem { label: qsTr("Disks"); value: cfg.disks ? cfg.disks.length : 0 }
            DetailItem { label: qsTr("Kernel cmdline"); value: cfg.cmdline || "-" }
            DetailItem { label: qsTr("crosvm log level"); value: cfg.log_level || "info" }
            DetailItem { label: qsTr("Extra crosvm args"); value: cfg.extra_args && cfg.extra_args.length ? cfg.extra_args.join(" ") : "-" }
            DetailItem { label: qsTr("Created"); value: cfg.created || "-" }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: !!cfg.notes
                text: cfg.notes || ""
                color: Theme.secondaryColor
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeExtraSmall
            }
        }

        VerticalScrollDecorator {}
    }
}
