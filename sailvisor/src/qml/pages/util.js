.pragma library

function stateColor(state) {
    switch (state) {
    case "running": return "#4caf50"
    case "starting":
    case "stopping": return "#ffb300"
    case "crashed":
    case "failed":
    case "dead": return "#ef5350"
    default: return "#9e9e9e"
    }
}

function isActive(state) {
    return state === "starting" || state === "running" || state === "stopping"
}

function duration(seconds) {
    if (seconds === undefined || seconds === null) return "-"
    var s = Math.floor(seconds)
    if (s < 60) return s + " s"
    if (s < 3600) return Math.floor(s / 60) + " min " + (s % 60) + " s"
    return Math.floor(s / 3600) + " h " + Math.floor((s % 3600) / 60) + " min"
}

function since(st, key) {
    if (!st || !st[key] || !st.started_at) return "-"
    return (st[key] - st.started_at).toFixed(1) + " s"
}

function statusIcon(status) {
    switch (status) {
    case "ok": return "✔"
    case "warn": return "!"
    case "fail": return "✖"
    default: return "i"
    }
}

function statusColor(status) {
    switch (status) {
    case "ok": return "#4caf50"
    case "warn": return "#ffb300"
    case "fail": return "#ef5350"
    default: return "#64b5f6"
    }
}

function splitArgs(text) {
    var parts = (text || "").split(" ")
    var out = []
    for (var i = 0; i < parts.length; i++)
        if (parts[i].length) out.push(parts[i])
    return out
}

function basename(path) {
    if (!path) return ""
    var i = path.lastIndexOf("/")
    return i >= 0 ? path.substring(i + 1) : path
}

function stripFileUrl(url) {
    var s = url ? url.toString() : ""
    return s.indexOf("file://") === 0 ? decodeURIComponent(s.substring(7)) : s
}
