import QtQuick 2.0
Page {
    property bool canAccept: true
    signal accepted()
    function accept() { if (!canAccept) { console.warn("STUB: accept() while canAccept=false"); return } accepted(); pageStack.pop() }
}
