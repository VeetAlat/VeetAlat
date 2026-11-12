.pragma library

// Where the photo goes in the ambience's square. Everything is a fraction
// of the square's side: the photo's centre (cx, cy) and its width (scale).
// The phone shows a centred rectangle of the square: in portrait, as wide
// as screenRatio (screen width / height) and as tall as the square; in
// landscape, as wide as the square and screenRatio tall. The corners are
// never seen.

// The photo's width as a fraction of the square, for each way of placing it.
// aspect is the photo's width / height, ratio the screen's width / height.
function scaleFor(preset, aspect, ratio) {
    switch (preset) {
    case "fillPortrait": return Math.max(ratio, aspect)          // covers the portrait screen
    case "fitPortrait": return Math.min(ratio, aspect)           // all of it on the portrait screen
    case "fillSquare": return Math.max(1, aspect)                // covers the whole square
    case "fitSquare": return Math.min(1, aspect)                 // all of it in the square
    case "fillLandscape": return Math.max(1, ratio * aspect)     // covers the landscape screen
    }
    return 1
}

function layoutFor(preset, aspect, ratio) {
    return { cx: 0.5, cy: 0.5, scale: scaleFor(preset, aspect, ratio) }
}

// The rectangle (fractions) the photo covers.
function photoRect(layout, aspect) {
    var w = layout.scale, h = layout.scale / aspect
    return { x: layout.cx - w / 2, y: layout.cy - h / 2, width: w, height: h }
}

// The rectangles the screens show.
function portraitRect(ratio) { return { x: (1 - ratio) / 2, y: 0, width: ratio, height: 1 } }
function landscapeRect(ratio) { return { x: 0, y: (1 - ratio) / 2, width: 1, height: ratio } }

function covers(outer, inner) {
    var e = 1e-9
    return outer.x <= inner.x + e && outer.y <= inner.y + e &&
           outer.x + outer.width >= inner.x + inner.width - e &&
           outer.y + outer.height >= inner.y + inner.height - e
}

// What the screens will show of the photo: for the hint under the editor.
function coverage(layout, aspect, ratio) {
    var p = photoRect(layout, aspect)
    return { portrait: covers(p, portraitRect(ratio)), landscape: covers(p, landscapeRect(ratio)) }
}

// Zooming by factor around a point (fractions): the point stays put.
function zoomed(layout, factor, px, py) {
    var s = Math.max(0.05, Math.min(10, layout.scale * factor))
    var f = s / layout.scale
    return { cx: px + (layout.cx - px) * f, cy: py + (layout.cy - py) * f, scale: s }
}

// The aspect after turning by rotation degrees.
function turnedAspect(width, height, rotation) {
    return (rotation % 180 === 0) ? width / height : height / width
}
