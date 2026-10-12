import QtQuick 2.0
import Sailfish.Silica 1.0
import "pages"
import "cover"

ApplicationWindow {
    id: app

    // the id must differ from the pages' "backend" property, or `backend: backend` binds to itself
    Backend {
        id: py
    }

    initialPage: Component {
        MainPage {
            backend: py
        }
    }

    cover: Component {
        CoverPage {
            backend: py
        }
    }

    allowedOrientations: defaultAllowedOrientations
}
