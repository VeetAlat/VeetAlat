import QtQuick 2.6
// A battery source that loads but never gives a charge.
Item {
    visible: false
    property bool ok: false
    property int percent: -1
    property bool charging
    property bool low
    property bool powerSave
}
