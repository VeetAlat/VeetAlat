import QtQuick 2.0
import io.thp.pyotherside 1.4

// Thin wrapper around the Python backend (sailvisor/bridge.py).
// run("fn", [args], onOk(result), onErr(message)) - every bridge function returns {ok, result|error}.
Python {
    id: py

    property bool ready: false
    property string lastError: ""
    property int pending: 0

    signal failed(string message)

    function run(fn, args, onOk, onErr) {
        pending += 1
        call("sailvisor.bridge." + fn, args || [], function(r) {
            pending -= 1
            if (r && r.ok) {
                if (onOk) onOk(r.result)
            } else {
                var msg = r ? r.error : qsTr("no response from backend")
                lastError = fn + ": " + msg
                console.warn("sailvisor: " + lastError)
                if (onErr) onErr(msg)
                else failed(msg)
            }
        })
    }

    Component.onCompleted: {
        var path = Qt.resolvedUrl("../python").toString()
        if (path.indexOf("file://") === 0)
            path = path.substring(7)
        addImportPath(path)
        importModule("sailvisor.bridge", function() {
            ready = true
            console.log("sailvisor: backend ready")
        })
    }

    onError: {
        lastError = traceback
        console.warn("sailvisor: python error: " + traceback)
        failed(traceback)
    }
}
