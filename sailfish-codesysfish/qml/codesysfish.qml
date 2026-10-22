import QtQuick 2.0
import Sailfish.Silica 1.0
import "pages"
import "cover"

ApplicationWindow {
    id: app

    // Named "thePlc", not "plc": pages have a "plc" property, and
    // "ProjectsPage { plc: plc }" would bind the page to its own empty
    // property instead of this object.
    Plc { id: thePlc }

    initialPage: Component {
        ProjectsPage { plc: thePlc }
    }
    cover: Component {
        CoverPage { plc: thePlc }
    }
    allowedOrientations: defaultAllowedOrientations
}
