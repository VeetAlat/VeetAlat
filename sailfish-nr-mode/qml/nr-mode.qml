import QtQuick 2.0
import Sailfish.Silica 1.0
import "pages"
import "cover"

ApplicationWindow {
    id: app

    // Shared for the whole app lifetime so the event timeline keeps
    // recording while its page is closed.
    Network { id: network }
    EventLog {
        id: events
        network: network
        control: nrControl
    }

    initialPage: Component {
        MainPage {
            network: network
            events: events
        }
    }
    cover: Component {
        CoverPage { network: network }
    }
    allowedOrientations: defaultAllowedOrientations
}
