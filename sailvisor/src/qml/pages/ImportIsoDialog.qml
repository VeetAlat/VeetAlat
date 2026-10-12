import QtQuick 2.0
import Sailfish.Silica 1.0
import Sailfish.Pickers 1.0

// Experimental: create a VM from a Linux arm64 ISO by extracting its kernel and initrd.
Dialog {
    id: dialog

    property var backend
    property var owner
    property var detected: null
    property string error: ""

    canAccept: detected !== null

    function inspect() {
        detected = null
        error = ""
        if (!pathField.text.length) return
        backend.run("inspect_iso", [pathField.text], function(info) {
            detected = info
            if (!nameField.text.length) nameField.text = info.label
        }, function(err) { error = err })
    }

    onAccepted: {
        var target = owner
        target.showMessage(qsTr("Importing ISO, extracting kernel..."))
        backend.run("import_iso", [pathField.text, nameField.text, Math.round(memSlider.value)], function(r) {
            target.showMessage(qsTr("Imported %1 (%2)").arg(r.id).arg(r.info.profile))
            target.refresh()
        }, function(err) { target.showMessage(qsTr("ISO import failed: %1").arg(err)) })
    }

    Component {
        id: picker
        FilePickerPage {
            title: qsTr("Select ISO")
            nameFilters: ["*.iso", "*.ISO"]
            onSelectedContentPropertiesChanged: {
                pathField.text = selectedContentProperties.filePath
                dialog.inspect()
            }
        }
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingSmall

            DialogHeader {
                title: qsTr("Import ISO")
                acceptText: qsTr("Import")
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                text: qsTr("Experimental. crosvm boots kernels directly, so Sailvisor extracts the kernel and initrd " +
                           "from an arm64 (aarch64) Linux ISO and attaches the ISO as a read-only disk. " +
                           "Works best with Ubuntu, Debian live, Alpine and Fedora live images.")
            }

            Row {
                width: parent.width
                TextField {
                    id: pathField
                    width: parent.width - browse.width - Theme.horizontalPageMargin
                    label: qsTr("ISO file")
                    placeholderText: label
                    inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                    EnterKey.onClicked: dialog.inspect()
                }
                Button { id: browse; text: qsTr("Browse"); width: Theme.itemSizeExtraLarge; onClicked: pageStack.push(picker) }
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: dialog.error.length > 0
                text: dialog.error
                color: "#ff6e6e"
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
            }

            DetailItem { visible: !!dialog.detected; label: qsTr("Detected"); value: dialog.detected ? dialog.detected.profile : "" }
            DetailItem { visible: !!dialog.detected; label: qsTr("Volume"); value: dialog.detected ? dialog.detected.label : "" }
            DetailItem { visible: !!dialog.detected; label: qsTr("Kernel"); value: dialog.detected ? dialog.detected.kernel : "" }
            DetailItem { visible: !!dialog.detected; label: qsTr("Initrd"); value: dialog.detected ? (dialog.detected.initrd || "-") : "" }
            DetailItem { visible: !!dialog.detected; label: qsTr("Cmdline"); value: dialog.detected ? dialog.detected.cmdline : "" }

            TextField {
                id: nameField
                width: parent.width
                label: qsTr("VM name")
                placeholderText: label
            }

            Slider {
                id: memSlider
                width: parent.width
                label: qsTr("Memory")
                minimumValue: 512
                maximumValue: 4096
                stepSize: 256
                value: 2048
                valueText: Math.round(value) + " MiB"
            }
        }
        VerticalScrollDecorator {}
    }
}
