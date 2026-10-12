import QtQuick 2.0
import Sailfish.Silica 1.0
import Sailfish.Pickers 1.0
import "util.js" as Util

// Create a VM, or edit one when vmId is set.
Dialog {
    id: dialog

    property var backend
    property var owner
    property string vmId: ""
    property var initial: ({})
    property var logLevels: ["error", "warn", "info", "debug", "trace"]
    property string pickTarget: ""

    canAccept: nameField.text.length > 0 && kernelField.text.length > 0

    function fields() {
        var disks = []
        if (diskField.text.length)
            disks.push({ path: diskField.text, ro: diskRo.checked })
        return {
            name: nameField.text,
            cpus: Math.round(cpuSlider.value),
            memory_mb: Math.round(memSlider.value),
            kernel: kernelField.text,
            initrd: initrdField.text,
            iso: isoField.text,
            disks: disks,
            cmdline: cmdlineField.text,
            log_level: logLevels[logCombo.currentIndex],
            extra_args: Util.splitArgs(extraField.text),
            notes: notesArea.text
        }
    }

    onAccepted: {
        var target = owner
        if (vmId) {
            backend.run("update_vm", [vmId, fields()], function() { if (target) target.refresh() },
                        function(err) { if (target) target.showMessage(err) })
        } else {
            backend.run("create_vm", [fields()], function() { if (target) target.refresh() },
                        function(err) { if (target) target.showMessage(err) })
        }
    }

    Component {
        id: picker
        FilePickerPage {
            title: qsTr("Select file")
            onSelectedContentPropertiesChanged: {
                var path = selectedContentProperties.filePath
                if (dialog.pickTarget === "kernel") kernelField.text = path
                else if (dialog.pickTarget === "initrd") initrdField.text = path
                else if (dialog.pickTarget === "iso") isoField.text = path
                else if (dialog.pickTarget === "disk") diskField.text = path
            }
        }
    }

    function pick(target) {
        pickTarget = target
        pageStack.push(picker)
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        Column {
            id: column
            width: parent.width

            DialogHeader {
                title: dialog.vmId ? qsTr("Edit VM") : qsTr("New VM")
                acceptText: qsTr("Save")
            }

            TextField {
                id: nameField
                width: parent.width
                label: qsTr("Name")
                placeholderText: label
                text: initial.name || ""
            }

            Slider {
                id: cpuSlider
                width: parent.width
                label: qsTr("vCPUs (GenieZone support is single-core for now)")
                minimumValue: 1
                maximumValue: 4
                stepSize: 1
                value: initial.cpus || 1
                valueText: Math.round(value)
            }

            Slider {
                id: memSlider
                width: parent.width
                label: qsTr("Memory")
                minimumValue: 128
                maximumValue: 4096
                stepSize: 128
                value: initial.memory_mb || 512
                valueText: Math.round(value) + " MiB"
            }

            SectionHeader { text: qsTr("Boot") }

            Row {
                width: parent.width
                TextField {
                    id: kernelField
                    width: parent.width - kernelBrowse.width - Theme.horizontalPageMargin
                    label: qsTr("Kernel (raw arm64 Image)")
                    placeholderText: label
                    text: initial.kernel || ""
                    inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                }
                Button { id: kernelBrowse; text: qsTr("Browse"); width: Theme.itemSizeExtraLarge; onClicked: dialog.pick("kernel") }
            }

            Row {
                width: parent.width
                TextField {
                    id: initrdField
                    width: parent.width - initrdBrowse.width - Theme.horizontalPageMargin
                    label: qsTr("Initrd (optional)")
                    placeholderText: label
                    text: initial.initrd || ""
                    inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                }
                Button { id: initrdBrowse; text: qsTr("Browse"); width: Theme.itemSizeExtraLarge; onClicked: dialog.pick("initrd") }
            }

            TextField {
                id: cmdlineField
                width: parent.width
                label: qsTr("Kernel command line")
                placeholderText: label
                text: initial.cmdline !== undefined ? initial.cmdline : "panic=-1"
                inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
            }

            SectionHeader { text: qsTr("Storage") }

            Row {
                width: parent.width
                TextField {
                    id: isoField
                    width: parent.width - isoBrowse.width - Theme.horizontalPageMargin
                    label: qsTr("ISO (attached read-only)")
                    placeholderText: label
                    text: initial.iso || ""
                    inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                }
                Button { id: isoBrowse; text: qsTr("Browse"); width: Theme.itemSizeExtraLarge; onClicked: dialog.pick("iso") }
            }

            Row {
                width: parent.width
                TextField {
                    id: diskField
                    width: parent.width - diskBrowse.width - Theme.horizontalPageMargin
                    label: qsTr("Disk image (optional)")
                    placeholderText: label
                    text: initial.disks && initial.disks.length ? initial.disks[0].path : ""
                    inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                }
                Button { id: diskBrowse; text: qsTr("Browse"); width: Theme.itemSizeExtraLarge; onClicked: dialog.pick("disk") }
            }

            TextSwitch {
                id: diskRo
                text: qsTr("Disk is read-only")
                checked: initial.disks && initial.disks.length ? !!initial.disks[0].ro : false
                visible: diskField.text.length > 0
            }

            SectionHeader { text: qsTr("Debugging") }

            ComboBox {
                id: logCombo
                width: parent.width
                label: qsTr("crosvm log level")
                currentIndex: Math.max(0, dialog.logLevels.indexOf(initial.log_level || "info"))
                menu: ContextMenu {
                    Repeater {
                        model: dialog.logLevels
                        MenuItem { text: modelData }
                    }
                }
            }

            TextField {
                id: extraField
                width: parent.width
                label: qsTr("Extra crosvm run arguments (advanced)")
                placeholderText: qsTr("e.g. --no-rng --no-usb")
                text: initial.extra_args ? initial.extra_args.join(" ") : ""
                inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
            }

            TextArea {
                id: notesArea
                width: parent.width
                label: qsTr("Notes")
                placeholderText: label
                text: initial.notes || ""
            }
        }
        VerticalScrollDecorator {}
    }
}
