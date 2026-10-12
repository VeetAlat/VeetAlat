import QtQuick 2.0
import Sailfish.Silica 1.0
import "util.js" as Util

Page {
    id: page

    property var backend
    property var owner
    property var checks: []
    property string overall: ""
    property bool running: false
    property var selftest: null
    property bool selftestRunning: false
    property string message: ""
    property string version: ""

    function runDoctor() {
        running = true
        backend.run("run_doctor", [], function(r) {
            checks = r.checks
            overall = r.overall
            running = false
        }, function(err) {
            running = false
            message = err
        })
    }

    function startSelftest() {
        message = ""
        selftest = null
        selftestRunning = true
        backend.run("selftest_start", [], function() {
            pollTimer.start()
            if (owner) owner.refresh()
        }, function(err) {
            selftestRunning = false
            message = qsTr("Self-test could not start: %1").arg(err)
        })
    }

    Timer {
        id: pollTimer
        interval: 1000
        repeat: true
        onTriggered: backend.run("selftest_result", [], function(r) {
            page.selftest = r
            if (r.finished) {
                pollTimer.stop()
                page.selftestRunning = false
                if (page.owner) page.owner.refresh()
            }
        })
    }

    Component.onCompleted: {
        runDoctor()
        backend.run("info", [], function(i) { version = i.version })
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        PullDownMenu {
            MenuItem {
                text: qsTr("App log")
                onClicked: pageStack.push(Qt.resolvedUrl("LogPage.qml"),
                                          { backend: backend, title: qsTr("App log"), fn: "app_log_tail", args: [65536] })
            }
            MenuItem {
                text: qsTr("Save debug report")
                onClicked: backend.run("save_report", [], function(path) {
                    Clipboard.text = path
                    message = qsTr("Report saved to %1 (path copied)").arg(path)
                }, function(err) { message = err })
            }
            MenuItem {
                text: qsTr("Re-run checks")
                onClicked: page.runDoctor()
            }
        }

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingSmall

            PageHeader {
                title: qsTr("Diagnostics")
                description: "Sailvisor " + page.version
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: page.message.length > 0
                text: page.message
                wrapMode: Text.Wrap
                color: Theme.highlightColor
                font.pixelSize: Theme.fontSizeSmall
            }

            SectionHeader { text: qsTr("Boot self-test") }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                text: qsTr("Boots the bundled test guest (1 vCPU, 256 MiB) with debug logging. " +
                           "It prints a banner and powers off. This is the real end-to-end test.")
            }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: page.selftestRunning ? qsTr("Running...") : qsTr("Run boot self-test")
                enabled: !page.selftestRunning
                onClicked: page.startSelftest()
            }

            Repeater {
                model: page.selftest ? page.selftest.checks : []
                Label {
                    x: Theme.horizontalPageMargin
                    width: column.width - 2 * x
                    text: (modelData.ok ? "✔ " : (page.selftestRunning ? "… " : "✖ ")) + modelData.title
                    color: modelData.ok ? "#4caf50" : (page.selftestRunning ? Theme.secondaryColor : "#ef5350")
                    font.pixelSize: Theme.fontSizeSmall
                }
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: !!page.selftest && page.selftest.finished
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeMedium
                color: page.selftest && page.selftest.passed ? "#4caf50" : "#ef5350"
                text: !page.selftest ? "" : (page.selftest.passed
                      ? qsTr("PASSED - a VM booted on GenieZone! 🎉")
                      : qsTr("FAILED: %1").arg(page.selftest.exit_reason || page.selftest.state))
            }

            Repeater {
                model: page.selftest && page.selftest.finished ? page.selftest.errors : []
                Label {
                    x: Theme.horizontalPageMargin
                    width: column.width - 2 * x
                    text: modelData
                    wrapMode: Text.WrapAnywhere
                    font.family: "monospace"
                    font.pixelSize: Theme.fontSizeTiny
                    color: "#ffab91"
                }
            }

            ButtonLayout {
                visible: !!page.selftest
                Button {
                    text: qsTr("Open self-test VM")
                    onClicked: pageStack.push(Qt.resolvedUrl("VmPage.qml"), { backend: backend, vmId: "selftest", owner: page.owner })
                }
                Button {
                    text: qsTr("Self-test log")
                    onClicked: pageStack.push(Qt.resolvedUrl("LogPage.qml"),
                                              { backend: backend, title: qsTr("Self-test VM log"), fn: "log_tail", args: ["selftest", "vm.log", 65536] })
                }
            }

            SectionHeader { text: qsTr("System checks") }

            BusyIndicator {
                anchors.horizontalCenter: parent.horizontalCenter
                size: BusyIndicatorSize.Medium
                running: page.running
                visible: running
            }

            Repeater {
                model: page.checks
                Item {
                    width: column.width
                    height: checkCol.height + Theme.paddingMedium

                    Label {
                        id: icon
                        x: Theme.horizontalPageMargin
                        width: Theme.iconSizeSmall
                        text: Util.statusIcon(modelData.status)
                        color: Util.statusColor(modelData.status)
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Column {
                        id: checkCol
                        anchors {
                            left: icon.right
                            leftMargin: Theme.paddingMedium
                            right: parent.right
                            rightMargin: Theme.horizontalPageMargin
                        }
                        Label {
                            width: parent.width
                            text: modelData.title
                            color: Theme.highlightColor
                            font.pixelSize: Theme.fontSizeSmall
                        }
                        Label {
                            width: parent.width
                            text: modelData.detail
                            textFormat: Text.PlainText
                            wrapMode: Text.WrapAnywhere
                            color: Theme.secondaryColor
                            font.pixelSize: Theme.fontSizeExtraSmall
                        }
                    }
                }
            }
        }
        VerticalScrollDecorator {}
    }
}
