import QtQuick 2.0
import Sailfish.Silica 1.0
import "pages"
import "cover"

ApplicationWindow {
    id: app

    // Deliberately not called "store": pages have a "store" property, and
    // "MainPage { store: store }" would resolve to the page's own (empty)
    // property instead of this object. That bug lost all saved data in 1.0.
    Store { id: appStore }

    initialPage: Component {
        MainPage { store: appStore }
    }
    cover: Component {
        CoverPage {
            store: appStore
            // Cover "+" button: open the app straight on the Add weight dialog.
            onAddRequested: {
                app.activate()
                pageStack.pop(null, PageStackAction.Immediate)
                pageStack.push(Qt.resolvedUrl("pages/AddEntryDialog.qml"), { store: appStore },
                               PageStackAction.Immediate)
            }
        }
    }
    allowedOrientations: defaultAllowedOrientations
}
