pragma Singleton
import QtQuick 2.0
// Stand-in for Silica's Theme, with values close to a dark ambience on a 1080px phone.
QtObject {
    property color primaryColor: "#ffffff"
    property color secondaryColor: "#a6ffffff"
    property color highlightColor: "#8fd4ff"
    property color secondaryHighlightColor: "#6ba6c8"
    property color highlightDimmerColor: "#0b1a24"
    property string fontFamily: "sans-serif"
    property int fontSizeExtraSmall: 24
    property int fontSizeSmall: 28
    property int fontSizeLarge: 40
    property int fontSizeHuge: 64
    property int paddingSmall: 6
    property int paddingMedium: 12
    property int paddingLarge: 24
    property int itemSizeHuge: 160
    property int itemSizeSmall: 80
    property int itemSizeMedium: 100
    property int itemSizeLarge: 110
    property int itemSizeExtraLarge: 190
    property int itemSizeExtraSmall: 70
    property int fontSizeExtraLarge: 50
    property int fontSizeMedium: 32
    property int buttonWidthLarge: 460
    property color highlightBackgroundColor: "#2a6a94"
    property real highlightBackgroundOpacity: 0.5
    property color errorColor: "#ff4d4d"
    property int horizontalPageMargin: 24
    function rgba(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
}
