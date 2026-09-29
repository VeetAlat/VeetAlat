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
            add("ARFCN", p.nrarfcn)
        } else if (cell.type === "lte") {
            add("RSRP", p.rsrp !== undefined ? -p.rsrp + " dBm" : undefined)
            add("RSRQ", p.rsrq !== undefined ? -p.rsrq + " dB" : undefined)
            add("SNR", p.rssnr !== undefined ? (p.rssnr / 10).toFixed(1) + " dB" : undefined)
            add("EARFCN", p.earfcn)
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
