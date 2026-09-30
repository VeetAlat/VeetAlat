import QtQuick 2.0
import Sailfish.Silica 1.0

// A short help text in the page margins.
Label {
    x: Theme.horizontalPageMargin
    width: (parent ? parent.width : 0) - 2 * x
    wrapMode: Text.Wrap
    font.pixelSize: Theme.fontSizeSmall
    color: Theme.secondaryHighlightColor
}
