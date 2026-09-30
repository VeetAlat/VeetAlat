import QtQuick 2.0
import Sailfish.Silica 1.0
import "pages"
import "cover"

ApplicationWindow {
    id: app

    Store { id: store }

    initialPage: Component {
        MainPage { store: store }
    }
    cover: Component {
        CoverPage {
            store: store
            // Cover "+" button: open the app straight on the Add weight dialog.
            onAddRequested: {
                app.activate()
                pageStack.pop(null, PageStackAction.Immediate)
                pageStack.push(Qt.resolvedUrl("pages/AddEntryDialog.qml"), { store: store },
                               PageStackAction.Immediate)
            }
        }
    }
    allowedOrientations: defaultAllowedOrientations
}
