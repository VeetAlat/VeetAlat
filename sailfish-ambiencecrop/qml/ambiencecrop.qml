import QtQuick 2.0
import Sailfish.Silica 1.0
import AmbienceCrop 1.0
import "pages"
import "cover"

ApplicationWindow {
    id: app

    // Named "theComposer", not "composer": pages have a "composer"
    // property, and "MainPage { composer: composer }" would bind the page
    // to its own empty property.
    Composer { id: theComposer }

    // The last image made, for the cover.
    property string lastImage: ""
    Connections {
        target: theComposer
        onSaved: if (path !== "") app.lastImage = path
    }

    initialPage: Component {
        MainPage { composer: theComposer }
    }
    cover: Component {
        CoverPage { image: app.lastImage }
    }
    allowedOrientations: defaultAllowedOrientations
}
