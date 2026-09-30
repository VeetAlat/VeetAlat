import QtQuick 2.0

// One of the three game buttons, drawn in neon: an arrow to the left or
// right, or the round jump button. It lights up while held down.
Item {
    id: button

    property string kind: "left"    // "left", "right" or "jump"
    property color color: "#19c6ff"
    property bool down: false

    onDownChanged: canvas.requestPaint()
    onWidthChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var w = width, h = height
            var pad = w * 0.1
            var c = button.color
            ctx.lineWidth = Math.max(3, w * 0.035)
            ctx.strokeStyle = c
            ctx.fillStyle = Qt.rgba(c.r, c.g, c.b, button.down ? 0.45 : 0.1)
            ctx.shadowColor = c
            ctx.shadowBlur = w * (button.down ? 0.16 : 0.08)

            ctx.beginPath()
            if (button.kind === "jump")
                ctx.arc(w / 2, h / 2, w / 2 - pad, 0, 2 * Math.PI, false)
            else
                ctx.roundedRect(pad, pad, w - 2 * pad, h - 2 * pad, w * 0.16, w * 0.16)
            ctx.fill()
            ctx.stroke()

            // The symbol: a filled arrow, or a ring inside the circle.
            ctx.fillStyle = button.down ? "#ffffff" : c
            ctx.beginPath()
            if (button.kind === "jump") {
                ctx.lineWidth = Math.max(4, w * 0.06)
                ctx.strokeStyle = button.down ? "#ffffff" : c
                ctx.arc(w / 2, h / 2, w * 0.17, 0, 2 * Math.PI, false)
                ctx.stroke()
            } else {
                var dir = button.kind === "left" ? -1 : 1
                var s = w * 0.2
                ctx.moveTo(w / 2 + dir * s, h / 2)
                ctx.lineTo(w / 2 - dir * s * 0.7, h / 2 - s)
                ctx.lineTo(w / 2 - dir * s * 0.7, h / 2 + s)
                ctx.closePath()
                ctx.fill()
            }
        }
    }
}
