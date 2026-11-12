import QtQuick 2.0
import Sailfish.Silica 1.0
import VeetPatched 1.0

// The patches, each with a switch. Flipping one asks the root helper to
// put it in or take it out; changes to the home screen show after
// restarting it, which is a button here.
Page {
    id: page

    property Patcher patcher
    property bool restartPending: false   // a change the home screen hasn't shown yet

    allowedOrientations: Orientation.All

    function message(action, r) {
        if (!r.ok) return r.message
        if (action === "restart-home") return "The home screen restarted."
        var name = ""
        for (var i = 0; i < patcher.patches.length; i++) {
            if (patcher.patches[i].id === r.patch) name = patcher.patches[i].name
        }
        if (action === "apply") return name + " is on. Restart the home screen to see it."
        if (action === "unapply") return name + " is off. Restart the home screen to see it gone."
        return ""
    }

    property string note: ""
    property bool noteIsError: false

    Connections {
        target: page.patcher
        onAnswered: {
            page.note = page.message(action, result)
            page.noteIsError = !result.ok
            if (result.ok && (action === "apply" || action === "unapply")) page.restartPending = true
            if (result.ok && action === "restart-home") page.restartPending = false
        }
    }

    Component.onCompleted: patcher.refresh()

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge * 2

        PullDownMenu {
            busy: page.patcher.busy
            MenuItem {
                text: "About"
                onClicked: pageStack.push(Qt.resolvedUrl("AboutPage.qml"))
            }
            MenuItem {
                text: "Log"
                onClicked: pageStack.push(Qt.resolvedUrl("LogPage.qml"), { patcher: page.patcher })
            }
            MenuItem {
                text: "Check again"
                enabled: !page.patcher.busy
                onClicked: page.patcher.refresh()
            }
        }

        VerticalScrollDecorator { }

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingMedium

            PageHeader {
                title: "VeetPatched"
                description: "Patches for your Sailfish phone"
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryHighlightColor
                text: "Each patch changes a little of the phone's own software. Switch one on or off, " +
                      "then restart the home screen. Switch them off before updating Sailfish OS."
            }

            Label {
                visible: !page.patcher.helperAnswers
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                color: Theme.errorColor
                text: "VeetPatched's helper isn't answering, so nothing can be changed right now. " +
                      "Restart the phone; if that doesn't help, reinstall VeetPatched."
            }

            Repeater {
                model: page.patcher.patches
                TextSwitch {
                    width: column.width
                    automaticCheck: false
                    checked: modelData.state === "applied"
                    busy: page.patcher.busy
                    enabled: !page.patcher.busy && modelData.state !== "missing"
                    text: modelData.name
                    description: modelData.description
                                 + (modelData.state === "missing" ? "\nNot available: this phone doesn't have the file it changes." : "")
                                 + (modelData.state === "unknown" ? "\nChecking…" : "")
                    onClicked: checked ? page.patcher.unapply(modelData.id) : page.patcher.apply(modelData.id)
                }
            }

            Label {
                visible: page.note !== ""
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                color: page.noteIsError ? Theme.errorColor : Theme.highlightColor
                text: page.note
            }

            Button {
                visible: page.restartPending
                anchors.horizontalCenter: parent.horizontalCenter
                preferredWidth: Theme.buttonWidthLarge
                text: "Restart home screen"
                enabled: !page.patcher.busy
                onClicked: page.patcher.restartHome()
            }
        }
    }
}
