
    // StatusBar (VeetPatched): a black bar over the notch with the time and status icons.
    // Loaded from its own file, so if it fails the app layer still works.
    Loader {
        property Item hostLayer: appLayer

        parent: appLayer.overlayItem
        width: parent ? parent.width : 0
        source: "file:///usr/share/veetpatched/patches/statusbar/NotchStatusBar.qml"
    }
