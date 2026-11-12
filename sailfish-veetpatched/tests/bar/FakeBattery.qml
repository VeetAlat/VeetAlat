import QtQuick 2.6
// A battery source that works, for the tests.
Item {
    visible: false
    property bool ok: true
    property int percent: 57
    property bool charging
    property bool low
    property bool powerSave
}
