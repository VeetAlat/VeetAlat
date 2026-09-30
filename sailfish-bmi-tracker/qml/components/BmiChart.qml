import QtQuick 2.0
import Sailfish.Silica 1.0
import "../js/bmi.js" as Bmi

// BMI over time on top of the four category bands. One series, so no
// legend box: the bands are named on the right edge. Tap or drag across
// the chart to see a measurement's date, weight and BMI.
Item {
    id: chart

    property var entries: []        // [{ date, weightKg, bmi }], oldest first
    property string weightUnit: "kg"
    property int selected: -1

    implicitHeight: Theme.itemSizeHuge * 2

    // Plot area (Item already has left/right/top/bottom)
    readonly property real plotLeft: Theme.fontSizeExtraSmall * 2.4        // fits "18.5"
    readonly property real plotRight: width - Theme.fontSizeExtraSmall * 4.2 // fits "Normal"
    readonly property real plotTop: Theme.paddingMedium
    readonly property real plotBottom: height - Theme.fontSizeExtraSmall * 2

    // BMI range shown: always the normal band plus some room around the data.
    readonly property var range: {
        var lo = 17, hi = 31
        for (var i = 0; i < entries.length; i++) {
            lo = Math.min(lo, Math.floor(entries[i].bmi - 1))
            hi = Math.max(hi, Math.ceil(entries[i].bmi + 1))
        }
        return { min: Math.max(10, lo), max: Math.min(60, hi) }
    }

    function dayOf(e) { return Date.parse(e.date + "T00:00:00") / 86400000 }
    function xAt(i) {
        if (entries.length < 2) return (plotLeft + plotRight) / 2
        var first = dayOf(entries[0]), last = dayOf(entries[entries.length - 1])
        if (last === first) return plotLeft + (plotRight - plotLeft) * i / (entries.length - 1)
        return plotLeft + (plotRight - plotLeft) * (dayOf(entries[i]) - first) / (last - first)
    }
    function yAt(bmi) {
        var p = (bmi - range.min) / (range.max - range.min)
        return plotBottom - Math.max(0, Math.min(1, p)) * (plotBottom - plotTop)
    }
    function dateText(iso) {
        var p = iso.split("-")
        return Qt.formatDate(new Date(p[0], p[1] - 1, p[2]), Qt.DefaultLocaleShortDate)
    }

    onEntriesChanged: { selected = -1; canvas.requestPaint() }
    onWidthChanged: canvas.requestPaint()
    onHeightChanged: canvas.requestPaint()
    onSelectedChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.clearRect(0, 0, width, height)
            var c = chart
            var font = Theme.fontSizeExtraSmall + "px \"" + Theme.fontFamily + "\""
            ctx.font = font

            // Category bands, 2px apart, with their names on the right.
            for (var b = 0; b < Bmi.categories.length; b++) {
                var cat = Bmi.categories[b]
                var lo = Math.max(cat.from, c.range.min), hi = Math.min(cat.to, c.range.max)
                if (hi <= lo) continue
                var y1 = c.yAt(hi) + 1, y2 = c.yAt(lo) - 1
                ctx.globalAlpha = 0.28
                ctx.fillStyle = cat.color
                ctx.fillRect(c.plotLeft, y1, c.plotRight - c.plotLeft, y2 - y1)
                ctx.globalAlpha = 1
                ctx.fillStyle = Theme.secondaryColor
                ctx.textAlign = "left"
                ctx.textBaseline = "middle"
                if (y2 - y1 > Theme.fontSizeExtraSmall) {
                    ctx.fillText(cat.shortName, c.plotRight + Theme.paddingSmall, (y1 + y2) / 2)
                }
            }

            // Boundary values on the left axis.
            ctx.fillStyle = Theme.secondaryColor
            ctx.textAlign = "right"
            ctx.textBaseline = "middle"
            var marks = [18.5, 25, 30]
            for (var m = 0; m < marks.length; m++) {
                if (marks[m] > c.range.min && marks[m] < c.range.max) {
                    ctx.fillText(String(marks[m]), c.plotLeft - Theme.paddingSmall, c.yAt(marks[m]))
                }
            }

            var n = c.entries.length
            if (n === 0) return

            // Dates of the first and last measurement.
            ctx.textBaseline = "bottom"
            ctx.textAlign = n > 1 ? "left" : "center"
            ctx.fillText(c.dateText(c.entries[0].date), n > 1 ? c.plotLeft : c.xAt(0), height)
            if (n > 1) {
                ctx.textAlign = "right"
                ctx.fillText(c.dateText(c.entries[n - 1].date), c.plotRight, height)
            }

            // Crosshair for the selected measurement.
            if (c.selected >= 0) {
                ctx.strokeStyle = Theme.secondaryColor
                ctx.lineWidth = 1
                ctx.beginPath()
                ctx.moveTo(c.xAt(c.selected), c.plotTop)
                ctx.lineTo(c.xAt(c.selected), c.plotBottom)
                ctx.stroke()
            }

            // The line, 2px.
            ctx.strokeStyle = Theme.primaryColor
            ctx.lineWidth = 2
            ctx.lineJoin = "round"
            ctx.beginPath()
            for (var i = 0; i < n; i++) {
                if (i === 0) ctx.moveTo(c.xAt(i), c.yAt(c.entries[i].bmi))
                else ctx.lineTo(c.xAt(i), c.yAt(c.entries[i].bmi))
            }
            ctx.stroke()

            // Points in their category colour with a 2px ring; the last
            // (and selected) one larger. Dense histories skip small dots.
            var ring = Theme.highlightDimmerColor
            for (var j = 0; j < n; j++) {
                var big = j === n - 1 || j === c.selected
                if (!big && n > 40) continue
                var r = big ? Theme.paddingSmall + 3 : Theme.paddingSmall
                ctx.beginPath()
                ctx.arc(c.xAt(j), c.yAt(c.entries[j].bmi), r + 2, 0, 2 * Math.PI)
                ctx.fillStyle = ring
                ctx.fill()
                ctx.beginPath()
                ctx.arc(c.xAt(j), c.yAt(c.entries[j].bmi), r, 0, 2 * Math.PI)
                ctx.fillStyle = Bmi.category(c.entries[j].bmi).color
                ctx.fill()
            }
        }
    }

    // Tap or drag to pick the nearest measurement. Vertical drags still
    // scroll the page.
    MouseArea {
        anchors.fill: parent
        enabled: chart.entries.length > 0
        function pick(mx) {
            var best = -1, bestDist = 1e9
            for (var i = 0; i < chart.entries.length; i++) {
                var d = Math.abs(chart.xAt(i) - mx)
                if (d < bestDist) { bestDist = d; best = i }
            }
            chart.selected = best
            hideTimer.restart()
        }
        onPressed: pick(mouse.x)
        onPositionChanged: pick(mouse.x)
    }

    Timer {
        id: hideTimer
        interval: 4000
        onTriggered: chart.selected = -1
    }

    // Tooltip
    Rectangle {
        id: tip
        readonly property var entry: chart.selected >= 0 ? chart.entries[chart.selected] : null
        visible: !!entry
        width: tipText.width + 2 * Theme.paddingMedium
        height: tipText.height + 2 * Theme.paddingSmall
        radius: Theme.paddingSmall
        color: Theme.rgba(Theme.highlightDimmerColor, 0.9)
        x: entry ? Math.max(0, Math.min(chart.width - width, chart.xAt(chart.selected) - width / 2)) : 0
        y: entry ? (chart.yAt(entry.bmi) > chart.height / 2
                    ? chart.yAt(entry.bmi) - height - Theme.paddingLarge
                    : chart.yAt(entry.bmi) + Theme.paddingLarge) : 0

        Label {
            id: tipText
            anchors.centerIn: parent
            font.pixelSize: Theme.fontSizeExtraSmall
            color: Theme.primaryColor
            text: tip.entry
                  ? chart.dateText(tip.entry.date) + "\n"
                    + Bmi.formatWeight(tip.entry.weightKg, chart.weightUnit)
                    + " · BMI " + Bmi.rounded(tip.entry.bmi).toFixed(1)
                    + " · " + Bmi.category(tip.entry.bmi).name
                  : ""
        }
    }
}
