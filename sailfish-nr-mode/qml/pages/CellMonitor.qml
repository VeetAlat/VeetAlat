import QtQuick 2.0
import Nemo.DBus 2.0

// Polls Sailfish ofono's CellInfo interface (org.nemomobile.ofono.CellInfo)
// for every cell the modem can see, serving and neighbours, with raw
// signal measurements. Android reports RSRP/RSRQ as positive numbers that
// mean negative dBm/dB and LTE RSSNR in tenths of a dB; format() converts.
QtObject {
    id: monitor

    property string modemPath
    property bool active: true

    // [{ path, type, registered, props }]
    property var cells: []
    readonly property var serving: {
        for (var i = 0; i < cells.length; i++) {
            if (cells[i].registered) return cells[i]
        }
        return null
    }
    readonly property int nrCellCount: count("nr")
    // Distinct bands of all visible cells, e.g. "n77/n78, b20".
    readonly property string bandSummary: {
        var seen = []
        for (var i = 0; i < cells.length; i++) {
            var b = band(cells[i])
            if (b && seen.indexOf(b) < 0) seen.push(b)
        }
        return seen.join(", ")
    }
    readonly property bool n77OnlySeen: bandSummary.indexOf("n77 only") >= 0

    function count(type) {
        var n = 0
        for (var i = 0; i < cells.length; i++) {
            if (cells[i].type === type) n++
        }
        return n
    }

    function typeName(type) {
        switch (type) {
        case "nr": return "5G NR"
        case "lte": return "4G LTE"
        case "wcdma": return "3G"
        case "gsm": return "2G"
        default: return type
        }
    }

    // NR-ARFCN to MHz (3GPP TS 38.104).
    function nrMhz(n) {
        if (n < 600000) return n * 0.005
        if (n < 2016667) return 3000 + (n - 600000) * 0.015
        return 24250.08 + (n - 2016667) * 0.06
    }

    // Band from channel number, for the bands used in Europe plus n77/n79.
    // 3.3-3.8 GHz is both n77 and n78; 3.8-4.2 GHz is n77 alone and needs
    // a modem with real n77 support.
    function band(cell) {
        var p = cell.props || {}
        var n
        if (cell.type === "nr" && p.nrarfcn !== undefined) {
            n = p.nrarfcn
            if (n >= 620000 && n <= 653333) return "n77/n78"
            if (n > 653333 && n <= 680000) return "n77 only"
            if (n >= 693334 && n <= 733333) return "n79"
            if (n >= 460000 && n <= 480000) return "n40"
            if (n >= 499200 && n <= 537999) return "n41"
            if (n >= 422000 && n <= 434000) return "n1"
            if (n >= 361000 && n <= 376000) return "n3"
            if (n >= 185000 && n <= 192000) return "n8"
            if (n >= 158200 && n <= 164200) return "n20"
            if (n >= 151600 && n <= 160600) return "n28"
            if (n >= 2054166 && n <= 2104165) return "n258"
            return "NR ?"
        }
        if (cell.type === "lte" && p.earfcn !== undefined) {
            n = p.earfcn
            if (n < 600) return "b1"
            if (n >= 1200 && n < 1950) return "b3"
            if (n >= 2750 && n < 3450) return "b7"
            if (n >= 3450 && n < 3800) return "b8"
            if (n >= 6150 && n < 6450) return "b20"
            if (n >= 9210 && n < 9660) return "b28"
            if (n >= 37750 && n < 38250) return "b38"
            if (n >= 38650 && n < 39650) return "b40"
            if (n >= 41590 && n < 43590) return "b42"
            if (n >= 43590 && n < 45590) return "b43"
            return "LTE ?"
        }
        return ""
    }

    // One-line summary of the signal values a cell reports.
    function format(cell) {
        if (!cell) return ""
        var p = cell.props || {}
        var parts = []
        function add(label, value) {
            if (value !== undefined) parts.push(label + " " + value)
        }
        if (cell.type === "nr") {
            add("RSRP", p.ssRsrp !== undefined ? -p.ssRsrp + " dBm" : undefined)
            add("RSRQ", p.ssRsrq !== undefined ? -p.ssRsrq + " dB" : undefined)
            add("SINR", p.ssSinr !== undefined ? p.ssSinr + " dB" : undefined)
            add("ARFCN", p.nrarfcn !== undefined
                ? p.nrarfcn + " (" + nrMhz(p.nrarfcn).toFixed(1) + " MHz, " + band(cell) + ")"
                : undefined)
        } else if (cell.type === "lte") {
            add("RSRP", p.rsrp !== undefined ? -p.rsrp + " dBm" : undefined)
            add("RSRQ", p.rsrq !== undefined ? -p.rsrq + " dB" : undefined)
            add("SNR", p.rssnr !== undefined ? (p.rssnr / 10).toFixed(1) + " dB" : undefined)
            add("EARFCN", p.earfcn !== undefined ? p.earfcn + " (" + band(cell) + ")" : undefined)
        } else {
            add("level", p.signalStrength)
        }
        add("PCI", p.pci)
        return parts.join(" · ")
    }

    function refresh() {
        if (!modemPath) {
            cells = []
            return
        }
        cellInfo.typedCall("GetCells", [], function(paths) {
            var result = []
            var pending = paths.length
            if (pending === 0) {
                cells = []
                return
            }
            paths.forEach(function(path) {
                var cell = { path: path, type: "", registered: false, props: {} }
                result.push(cell)
                var iface = cellInterface(path)
                var calls = 3
                function done() {
                    if (--calls === 0 && --pending === 0) {
                        monitor.cells = result
                    }
                }
                iface.typedCall("GetType", [], function(t) { cell.type = t; done() }, done)
                iface.typedCall("GetRegistered", [], function(r) { cell.registered = r; done() }, done)
                iface.typedCall("GetProperties", [], function(p) { cell.props = p; done() }, done)
            })
        }, function() {
            cells = []
        })
    }

    // One DBusInterface per cell path, reused across polls.
    property var interfaces: ({})
    function cellInterface(path) {
        if (!interfaces[path]) {
            interfaces[path] = cellComponent.createObject(monitor, { path: path })
        }
        return interfaces[path]
    }

    property Component cellComponent: Component {
        DBusInterface {
            bus: DBus.SystemBus
            service: "org.ofono"
            iface: "org.nemomobile.ofono.Cell"
        }
    }

    property DBusInterface cellInfo: DBusInterface {
        bus: DBus.SystemBus
        service: "org.ofono"
        path: monitor.modemPath || "/"
        iface: "org.nemomobile.ofono.CellInfo"
    }

    property Timer timer: Timer {
        interval: 5000
        repeat: true
        triggeredOnStart: true
        running: monitor.active && monitor.modemPath !== ""
        onTriggered: monitor.refresh()
    }
}
