import QtQuick 2.0
import Sailfish.Silica 1.0
import CodeSysFish 1.0
import "../js/store.js" as Store
import "../js/st.js" as St

// A project's code: Structured Text with syntax highlighting, a bar of
// symbols that are awkward on a phone keyboard, and Build and Run. Build
// lists the errors and warnings; tap one to go to its line. The code is
// saved as it's typed.
Page {
    id: page

    property Plc plc
    property int projectId: -1
    property var project: null
    readonly property string name: project ? project.name : ""

    property var messages: []      // the last build's errors and warnings
    property string buildStatus: ""
    property bool buildOk: false
    property bool dirty: false
    property bool _loading: true
    property int _lastLength: 0

    readonly property alias editorArea: editor
    readonly property alias codeHighlighter: highlighter
    readonly property int cursorLine: editor.text.substr(0, editor.cursorPosition).split("\n").length

    allowedOrientations: Orientation.All

    function save() {
        if (!dirty || projectId < 0) return
        Store.save(projectId, editor.text)
        dirty = false
    }

    // Compiles the code: the result ({ ok, errors, warnings }).
    function build() {
        save()
        var result = plc.build(editor.text)
        messages = result.errors.concat(result.warnings).sort(function(a, b) {
            return a.line - b.line || a.col - b.col
        })
        var e = result.errors.length, w = result.warnings.length
        buildOk = result.ok
        buildStatus = result.ok
            ? "Build OK" + (w > 0 ? ", " + w + (w === 1 ? " warning" : " warnings") : "")
            : e + (e === 1 ? " error" : " errors") + (w > 0 ? ", " + w + (w === 1 ? " warning" : " warnings") : "")
        highlighter.errorLine = e > 0 ? result.errors[0].line : 0
        return result
    }

    // Builds, loads the PLC and starts it: the online view, or null.
    function run() {
        var result = build()
        if (!result.ok) return null
        var problem = plc.load(projectId, name, editor.text)
        if (problem !== "") return null
        plc.start()
        return pageStack.push(Qt.resolvedUrl("RunPage.qml"), { plc: plc, editorPage: page })
    }

    // Puts the cursor at a line (and column), and scrolls to it.
    function goToLine(line, col) {
        var lines = editor.text.split("\n")
        var pos = 0
        for (var i = 0; i < Math.min(line - 1, lines.length); i++) pos += lines[i].length + 1
        pos = Math.min(editor.text.length, pos + Math.max(0, (col || 1) - 1))
        editor.cursorPosition = pos
        editor.forceActiveFocus()
        var r = editor.positionToRectangle(pos)
        var y = editor.y + r.y - flick.height / 3
        flick.contentY = Math.max(0, Math.min(y, flick.contentHeight - flick.height))
    }

    // Types text at the cursor; the cursor ends at cursorAt (default: after it).
    function insert(text, cursorAt) {
        var pos = editor.cursorPosition
        if (text.indexOf("\n") >= 0) {
            // A snippet's lines follow the current line's indentation.
            var start = editor.text.lastIndexOf("\n", pos - 1) + 1
            var indent = /^[ \t]*/.exec(editor.text.substring(start, pos))[0]
            if (indent.length > 0) {
                var at = cursorAt === undefined ? text.length : cursorAt
                cursorAt = at + (text.substr(0, at).split("\n").length - 1) * indent.length
                text = text.replace(/\n/g, "\n" + indent)
            }
        }
        editor._editor.insert(pos, text)
        editor.cursorPosition = pos + (cursorAt === undefined ? text.length : cursorAt)
    }

    onStatusChanged: if (status === PageStatus.Deactivating) save()

    Component.onCompleted: {
        project = Store.get(projectId)
        editor.text = project ? project.source : ""
        _lastLength = editor.text.length
        _loading = false
    }

    Timer {
        id: autosave
        interval: 1500
        onTriggered: page.save()
    }

    StHighlighter {
        id: highlighter
        textDocument: editor._editor.textDocument
        readonly property var words: St.highlightWords()
        readonly property bool light: Theme.colorScheme === Theme.DarkOnLight
        keywords: words.keywords
        types: words.types
        functions: words.functions
        keywordColor: light ? "#a35a00" : "#ffcc66"
        typeColor: light ? "#00639e" : "#66ccff"
        functionColor: light ? "#2e7d32" : "#99e699"
        literalColor: light ? "#ad1457" : "#ff99cc"
        stringColor: light ? "#b34700" : "#ffb380"
        commentColor: light ? "#757575" : "#9a9a9a"
        errorColor: Theme.errorColor
    }

    Column {
        id: top
        width: parent.width

        PageHeader {
            title: page.name
            description: "Line " + page.cursorLine + (page.buildStatus ? " · " + page.buildStatus : "")
        }

        Row {
            x: Theme.horizontalPageMargin
            spacing: Theme.paddingMedium
            height: buildButton.height + Theme.paddingSmall

            Button {
                id: buildButton
                preferredWidth: Theme.buttonWidthExtraSmall
                text: "Build"
                onClicked: page.build()
            }
            Button {
                preferredWidth: Theme.buttonWidthExtraSmall
                text: "Run"
                color: Theme.highlightColor
                onClicked: page.run()
            }
            Button {
                preferredWidth: Theme.buttonWidthExtraSmall
                text: "Help"
                onClicked: pageStack.push(Qt.resolvedUrl("HelpPage.qml"))
            }
        }

        // The build's messages: tap one to go to its line.
        Item {
            width: parent.width
            height: page.messages.length > 0 ? Math.min(messageList.contentHeight, Theme.itemSizeSmall * 3) + Theme.paddingSmall : 0
            clip: true
            visible: height > 0

            SilicaListView {
                id: messageList
                anchors.fill: parent
                model: page.messages
                delegate: BackgroundItem {
                    width: messageList.width
                    height: messageLabel.height + Theme.paddingSmall * 2
                    onClicked: page.goToLine(modelData.line, modelData.col)
                    Label {
                        id: messageLabel
                        x: Theme.horizontalPageMargin
                        y: Theme.paddingSmall
                        width: parent.width - 2 * x
                        wrapMode: Text.Wrap
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: modelData.severity === "error" ? Theme.errorColor : Theme.secondaryHighlightColor
                        text: (modelData.severity === "error" ? "Error" : "Warning") + ", line " + modelData.line + ": " + modelData.message
                    }
                }
                VerticalScrollDecorator { }
            }
        }
    }

    SilicaFlickable {
        id: flick
        anchors {
            top: top.bottom
            bottom: symbols.top
            left: parent.left
            right: parent.right
        }
        contentHeight: editor.height
        clip: true

        PullDownMenu {
            MenuItem {
                text: "Copy all code"
                onClicked: Clipboard.text = editor.text
            }
            MenuItem {
                text: "Rename"
                onClicked: {
                    var dialog = pageStack.push(Qt.resolvedUrl("RenameDialog.qml"), { name: page.name })
                    dialog.accepted.connect(function() {
                        Store.rename(page.projectId, dialog.name)
                        page.project = Store.get(page.projectId)
                        if (page.plc.projectId === page.projectId) page.plc.projectName = dialog.name
                    })
                }
            }
            MenuItem {
                text: page.plc.loaded && page.plc.projectId === page.projectId ? "Online view" : ""
                visible: text !== ""
                onClicked: pageStack.push(Qt.resolvedUrl("RunPage.qml"), { plc: page.plc, editorPage: page })
            }
        }

        TextArea {
            id: editor
            width: flick.width
            font.family: "DejaVu Sans Mono"
            font.pixelSize: Theme.fontSizeExtraSmall
            wrapMode: TextEdit.Wrap
            labelVisible: false
            placeholderText: "PROGRAM PLC_PRG ..."
            inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
            // Tapping the symbol bar mustn't close the keyboard.
            focusOutBehavior: FocusBehavior.KeepFocus

            onTextChanged: {
                if (page._loading) return
                page.dirty = true
                autosave.restart()
                // A new line starts with the indentation of the one before.
                var t = text, c = cursorPosition
                if (t.length === page._lastLength + 1 && c > 0 && t.charAt(c - 1) === "\n") {
                    var start = t.lastIndexOf("\n", c - 2) + 1
                    var indent = /^[ \t]*/.exec(t.substring(start, c - 1))[0]
                    page._lastLength = t.length + indent.length
                    if (indent.length > 0) page.insert(indent)
                    return
                }
                page._lastLength = t.length
            }
        }

        VerticalScrollDecorator { }
    }

    // Symbols and snippets, above the keyboard.
    Rectangle {
        id: symbols
        anchors.bottom: parent.bottom
        width: parent.width
        height: Theme.itemSizeSmall
        color: Theme.rgba(Theme.highlightBackgroundColor, 0.15)

        readonly property var keys: [
            { label: ":=", text: " := " }, { label: ";", text: ";" },
            { label: "( )", text: "()", at: 1 }, { label: "[ ]", text: "[]", at: 1 },
            { label: "'", text: "''", at: 1 }, { label: ".", text: "." }, { label: ",", text: ", " },
            { label: ":", text: " : " }, { label: "=", text: " = " }, { label: "<", text: " < " },
            { label: ">", text: " > " }, { label: "+", text: " + " }, { label: "-", text: " - " },
            { label: "*", text: " * " }, { label: "/", text: " / " }, { label: "#", text: "#" },
            { label: "_", text: "_" }, { label: "⇥", text: "    " },
            { label: "IF", text: "IF  THEN\n    \nEND_IF", at: 3 },
            { label: "ELSIF", text: "ELSIF  THEN\n    ", at: 6 },
            { label: "ELSE", text: "ELSE\n    " },
            { label: "FOR", text: "FOR i := 1 TO 10 DO\n    \nEND_FOR", at: 24 },
            { label: "WHILE", text: "WHILE  DO\n    \nEND_WHILE", at: 6 },
            { label: "CASE", text: "CASE  OF\n    1:\n        \nEND_CASE", at: 5 },
            { label: "VAR", text: "VAR\n    \nEND_VAR", at: 8 },
            { label: "TRUE", text: "TRUE" }, { label: "FALSE", text: "FALSE" },
            { label: "NOT", text: "NOT " }, { label: "AND", text: " AND " }, { label: "OR", text: " OR " },
            { label: "T#", text: "T#" }, { label: "TON", text: "TON;" }
        ]

        ListView {
            id: keyList
            anchors.fill: parent
            orientation: ListView.Horizontal
            model: symbols.keys
            clip: true
            delegate: BackgroundItem {
                width: Math.max(Theme.itemSizeSmall * 0.9, keyLabel.implicitWidth + 2 * Theme.paddingMedium)
                height: keyList.height
                onClicked: page.insert(modelData.text, modelData.at)
                Label {
                    id: keyLabel
                    anchors.centerIn: parent
                    font.family: "DejaVu Sans Mono"
                    font.pixelSize: Theme.fontSizeSmall
                    color: parent.highlighted ? Theme.highlightColor : Theme.primaryColor
                    text: modelData.label
                }
            }
        }
    }
}
