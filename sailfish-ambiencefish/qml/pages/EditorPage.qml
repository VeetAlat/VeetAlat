import QtQuick 2.5
import Sailfish.Silica 1.0
import AmbienceFish 1.0
import "../js/layout.js" as Layout

// The square the ambience will use, with the photo on it: drag to move,
// pinch to zoom, double-tap to fill the screen again. The bright frame is
// what the phone shows held upright, the dashed one what it shows turned
// sideways; the darker corners are never seen. Around the photo goes a
// blur of it (or its colour, or black).
Page {
    id: page

    property Composer composer
    property string source

    // The photo, as shown (its EXIF orientation applied), and the turn on top.
    property int photoWidth: 1
    property int photoHeight: 1
    property bool photoOk: true
    property string photoError: ""
    property int turn: 0
    readonly property real aspect: Layout.turnedAspect(photoWidth, photoHeight, turn)

    // The screen's shape: what the ambience is cut to.
    readonly property real screenRatio: Math.min(Screen.width, Screen.height) / Math.max(Screen.width, Screen.height)

    // Where the photo is (fractions of the square).
    property real cx: 0.5
    property real cy: 0.5
    property real photoScale: 1
    property string preset: "fillPortrait"

    property string fill: "blur"   // around the photo: "blur", "colour" or "black"
    property real blur: 0.6
    property real dim: 0.25
    property string guide: "both"        // "both", "portrait", "landscape" or "profile"

    property string previewUrl: ""
    readonly property alias canvasItem: canvas
    readonly property alias photoItem: photoBox

    readonly property var coverage: Layout.coverage({ cx: cx, cy: cy, scale: photoScale }, aspect, screenRatio)

    allowedOrientations: Orientation.Portrait

    function layout() {
        return { size: Math.max(2048, Math.min(4096, Math.max(Screen.width, Screen.height))),
                 cx: cx, cy: cy, scale: photoScale, rotation: turn,
                 background: fill, blur: blur, dim: dim }
    }

    function apply(name) {
        var l = Layout.layoutFor(name, aspect, screenRatio)
        cx = l.cx
        cy = l.cy
        photoScale = l.scale
        preset = name
    }

    function rotate() {
        turn = (turn + 90) % 360
        apply(preset)
        refreshPreview()
    }

    function refreshPreview() { previewTimer.restart() }

    function save() {
        if (composer.busy || !photoOk) return
        composer.save(source, layout())
    }

    Component.onCompleted: {
        var info = composer.inspect(source)
        photoOk = info.ok
        if (info.ok) {
            photoWidth = info.width
            photoHeight = info.height
            apply("fillPortrait")
            previewUrl = composer.previewBackground(source, 512, layout())
        } else {
            photoError = info.error || "The photo couldn't be read"
        }
    }

    onFillChanged: refreshPreview()
    onBlurChanged: refreshPreview()
    onDimChanged: refreshPreview()

    Timer {
        id: previewTimer
        interval: 150
        onTriggered: if (page.photoOk) page.previewUrl = page.composer.previewBackground(page.source, 512, page.layout())
    }

    Connections {
        target: page.composer
        onSaved: {
            if (page.status !== PageStatus.Active) return
            if (error !== "") {
                saveError.text = error
                return
            }
            pageStack.push(Qt.resolvedUrl("DonePage.qml"), { composer: page.composer, path: path })
        }
    }

    SilicaFlickable {
        id: flick
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        PullDownMenu {
            busy: page.composer.busy
            MenuItem {
                text: "Save"
                enabled: page.photoOk && !page.composer.busy
                onClicked: page.save()
            }
        }

        VerticalScrollDecorator { }

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingMedium

            PageHeader {
                title: "Frame it"
                description: page.coverage.portrait
                             ? (page.coverage.landscape ? "The photo fills both screens" : "Fills the screen; turned sideways, the blur shows")
                             : "The blur shows around the photo"
            }

            Label {
                visible: !page.photoOk
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                color: Theme.errorColor
                text: "This photo couldn't be opened: " + page.photoError
            }

            // The square.
            Item {
                id: canvas
                visible: page.photoOk
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                height: width
                clip: true

                Rectangle {
                    anchors.fill: parent
                    color: "black"
                }
                Image {
                    anchors.fill: parent
                    source: page.previewUrl
                    fillMode: Image.Stretch
                    smooth: true
                    cache: false
                    asynchronous: false
                }

                // The photo: a box the size it takes, the photo turned inside.
                Item {
                    id: photoBox
                    x: (page.cx - page.photoScale / 2) * canvas.width
                    y: (page.cy - page.photoScale / page.aspect / 2) * canvas.width
                    width: page.photoScale * canvas.width
                    height: width / page.aspect

                    Image {
                        id: photo
                        anchors.centerIn: parent
                        width: page.turn % 180 === 0 ? parent.width : parent.height
                        height: page.turn % 180 === 0 ? parent.height : parent.width
                        rotation: page.turn
                        source: page.photoOk ? page.source : ""
                        autoTransform: true
                        asynchronous: true
                        smooth: true
                        fillMode: Image.Stretch
                        sourceSize.width: 1600
                        sourceSize.height: 1600
                    }
                }

                // What the screens show. Outside the chosen one is shaded.
                Item {
                    id: guides
                    anchors.fill: parent

                    readonly property real r: page.screenRatio
                    readonly property int dashes: 12
                    readonly property var shown: page.guide === "landscape" ? Layout.landscapeRect(r)
                                               : page.guide === "profile" ? { x: 0, y: 0, width: 1, height: 1 }
                                               : Layout.portraitRect(r)

                    // Shade outside the shown area (four sides).
                    Rectangle {
                        visible: page.guide !== "profile"
                        color: Qt.rgba(0, 0, 0, 0.55)
                        x: 0; y: 0; width: parent.width; height: guides.shown.y * parent.height
                    }
                    Rectangle {
                        visible: page.guide !== "profile"
                        color: Qt.rgba(0, 0, 0, 0.55)
                        x: 0; y: (guides.shown.y + guides.shown.height) * parent.height
                        width: parent.width; height: parent.height - y
                    }
                    Rectangle {
                        visible: page.guide !== "profile"
                        color: Qt.rgba(0, 0, 0, 0.55)
                        x: 0; y: guides.shown.y * parent.height
                        width: guides.shown.x * parent.width; height: guides.shown.height * parent.height
                    }
                    Rectangle {
                        visible: page.guide !== "profile"
                        color: Qt.rgba(0, 0, 0, 0.55)
                        x: (guides.shown.x + guides.shown.width) * parent.width; y: guides.shown.y * parent.height
                        width: parent.width - x; height: guides.shown.height * parent.height
                    }

                    // The portrait screen's frame.
                    Rectangle {
                        visible: page.guide === "both" || page.guide === "portrait"
                        color: "transparent"
                        border.color: "white"
                        border.width: Math.max(2, Theme.paddingSmall / 3)
                        x: Layout.portraitRect(guides.r).x * parent.width
                        width: guides.r * parent.width
                        height: parent.height
                    }
                    // The landscape screen's frame: dashed lines along its top and bottom.
                    Repeater {
                        model: page.guide === "both" || page.guide === "landscape" ? 2 * guides.dashes : 0
                        Rectangle {
                            readonly property real step: canvas.width / guides.dashes
                            readonly property bool atBottom: index >= guides.dashes
                            color: Theme.highlightColor
                            x: (index % guides.dashes) * step
                            y: atBottom ? (Layout.landscapeRect(guides.r).y + guides.r) * canvas.height - height
                                      : Layout.landscapeRect(guides.r).y * canvas.height
                            width: step * 0.6
                            height: Math.max(2, Theme.paddingSmall / 3)
                        }
                    }
                    // A profile photo's circle.
                    Rectangle {
                        visible: page.guide === "profile"
                        anchors.fill: parent
                        radius: width / 2
                        color: "transparent"
                        border.color: "white"
                        border.width: Math.max(2, Theme.paddingSmall / 3)
                    }
                }

                // Drag, pinch, double-tap.
                PinchArea {
                    id: pinch
                    anchors.fill: parent
                    property real startScale: 1
                    property real startCx: 0.5
                    property real startCy: 0.5
                    onPinchStarted: {
                        startScale = page.photoScale
                        startCx = page.cx
                        startCy = page.cy
                    }
                    onPinchUpdated: {
                        var px = pinch.startCenter.x / canvas.width, py = pinch.startCenter.y / canvas.height
                        var z = Layout.zoomed({ cx: startCx, cy: startCy, scale: startScale },
                                              pinch.scale, px, py)
                        page.photoScale = z.scale
                        page.cx = z.cx + (pinch.center.x - pinch.startCenter.x) / canvas.width
                        page.cy = z.cy + (pinch.center.y - pinch.startCenter.y) / canvas.height
                        page.preset = ""
                    }

                    MouseArea {
                        anchors.fill: parent
                        preventStealing: true
                        property real lastX
                        property real lastY
                        onPressed: { lastX = mouse.x; lastY = mouse.y }
                        onPositionChanged: {
                            page.cx += (mouse.x - lastX) / canvas.width
                            page.cy += (mouse.y - lastY) / canvas.height
                            lastX = mouse.x
                            lastY = mouse.y
                            page.preset = ""
                        }
                        onDoubleClicked: page.apply(page.preset === "fillPortrait" ? "fitPortrait" : "fillPortrait")
                    }
                }
            }

            Label {
                visible: page.photoOk
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                text: "Drag to move, pinch to zoom, double-tap to switch between filling the screen and the whole photo."
            }

            // Ready-made placements.
            Flow {
                visible: page.photoOk
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                spacing: Theme.paddingMedium

                Repeater {
                    model: [
                        { name: "fillPortrait", label: "Fill screen" },
                        { name: "fitPortrait", label: "Whole photo" },
                        { name: "fillSquare", label: "Fill square" },
                        { name: "fillLandscape", label: "Fill sideways" }
                    ]
                    Button {
                        preferredWidth: (parent.width - Theme.paddingMedium) / 2
                        text: modelData.label
                        down: page.preset === modelData.name || pressed
                        onClicked: page.apply(modelData.name)
                    }
                }
                Button {
                    preferredWidth: (parent.width - Theme.paddingMedium) / 2
                    text: "Centre"
                    onClicked: { page.cx = 0.5; page.cy = 0.5 }
                }
                Button {
                    preferredWidth: (parent.width - Theme.paddingMedium) / 2
                    text: "Turn ↻"
                    onClicked: page.rotate()
                }
            }

            ComboBox {
                visible: page.photoOk
                width: parent.width
                label: "Show"
                readonly property var values: ["both", "portrait", "landscape", "profile"]
                currentIndex: values.indexOf(page.guide)
                menu: ContextMenu {
                    MenuItem { text: "Both screens" }
                    MenuItem { text: "Phone upright" }
                    MenuItem { text: "Phone sideways" }
                    MenuItem { text: "Profile photo circle" }
                }
                onCurrentIndexChanged: page.guide = values[currentIndex]
            }

            ComboBox {
                visible: page.photoOk
                width: parent.width
                label: "Around the photo"
                readonly property var values: ["blur", "colour", "black"]
                currentIndex: values.indexOf(page.fill)
                menu: ContextMenu {
                    MenuItem { text: "Blurred photo" }
                    MenuItem { text: "The photo's colour" }
                    MenuItem { text: "Black" }
                }
                onCurrentIndexChanged: page.fill = values[currentIndex]
            }

            Slider {
                visible: page.photoOk && page.fill === "blur"
                width: parent.width
                label: "Blur"
                minimumValue: 0
                maximumValue: 1
                stepSize: 0.05
                value: page.blur
                valueText: Math.round(value * 100) + " %"
                onValueChanged: page.blur = value
            }

            Slider {
                visible: page.photoOk && page.fill !== "black"
                width: parent.width
                label: "Darken the surroundings"
                minimumValue: 0
                maximumValue: 0.9
                stepSize: 0.05
                value: page.dim
                valueText: Math.round(value * 100) + " %"
                onValueChanged: page.dim = value
            }

            Label {
                id: saveError
                visible: text !== ""
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                color: Theme.errorColor
            }

            Button {
                visible: page.photoOk
                anchors.horizontalCenter: parent.horizontalCenter
                preferredWidth: Theme.buttonWidthLarge
                text: page.composer.busy ? "Saving…" : "Save"
                enabled: !page.composer.busy
                onClicked: page.save()
            }
        }
    }
}
