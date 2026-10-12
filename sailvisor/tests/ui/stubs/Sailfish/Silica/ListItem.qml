import QtQuick 2.0
Item {
    property real contentHeight: 80
    property var menu
    property bool highlighted: false
    signal clicked()
    width: ListView.view ? ListView.view.width : 100
    height: contentHeight
    function remorseAction(text, cb, timeout) { cb() }
}
