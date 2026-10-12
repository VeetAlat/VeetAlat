import QtQuick 2.0
Item {
    id: win
    width: 540; height: 960
    property var initialPage
    property var cover
    property int allowedOrientations: 0
    property int defaultAllowedOrientations: 15
    property var coverItem: null
    property alias pageStack: stack

    Item {
        id: stack
        anchors.fill: parent
        property var pages: []
        property var currentPage: pages.length ? pages[pages.length - 1] : null
        property int depth: pages.length
        function _activate() {
            for (var i = 0; i < pages.length; i++) pages[i].status = (i === pages.length - 1) ? 2 : 0
            currentPage = pages.length ? pages[pages.length - 1] : null
            depth = pages.length
        }
        function push(page, props) {
            var comp = (typeof page === "string" || page.toString().indexOf("file:") === 0 || page.toString().indexOf("qrc:") === 0)
                       ? Qt.createComponent(page) : page
            if (comp.status === Component.Error) { console.error("STUB push failed: " + comp.errorString()); return null }
            var obj = comp.createObject(stack, props || {})
            if (!obj) { console.error("STUB push: createObject failed for " + page); return null }
            var p = pages.slice(); p.push(obj); pages = p
            _activate()
            console.log("STUB: pushed " + page)
            return obj
        }
        function pop() {
            var p = pages.slice(); var obj = p.pop(); pages = p
            _activate()
            obj.destroy()
        }
    }

    Component.onCompleted: {
        stack.push(initialPage)
        if (cover) coverItem = cover.createObject(win)
        if (Qt.application.arguments.indexOf("--ui-test") >= 0) {
            var c = Qt.createComponent(Qt.resolvedUrl("../../../Driver.qml"))
            if (c.status === Component.Error) console.error(c.errorString())
            c.createObject(win, { win: win })
        }
    }
}
