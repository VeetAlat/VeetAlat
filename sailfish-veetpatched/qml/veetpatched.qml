import QtQuick 2.0
import Sailfish.Silica 1.0
import VeetPatched 1.0
import "pages"
import "cover"

ApplicationWindow {
    id: app

    // Named "thePatcher": pages have a "patcher" property.
    Patcher { id: thePatcher }

    initialPage: Component {
        MainPage { patcher: thePatcher }
    }
    cover: Component {
        CoverPage { patcher: thePatcher }
    }
    allowedOrientations: defaultAllowedOrientations
}
