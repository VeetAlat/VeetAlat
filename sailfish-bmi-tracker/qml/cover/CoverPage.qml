import QtQuick 2.0
import Sailfish.Silica 1.0
import "../pages"
import "../js/bmi.js" as Bmi

// The home screen cover: the app's name, the latest weight and its date,
// with a faint scale gauge behind. The gauge is a picture rather than a
// Canvas, since covers are drawn while the app is in the background, where
// a Canvas can lose what it drew.
CoverBackground {
    id: cover

    property Store store
    signal addRequested()

    readonly property var latest: store ? store.latest : null
    readonly property string latestWeightText:
        latest ? Bmi.formatWeight(latest.weightKg, store.weightUnit) : ""
    readonly property string latestDateText:
        latest ? Qt.formatDate(store.parseIsoDate(latest.date), Qt.DefaultLocaleShortDate) : ""

    Image {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.itemSizeSmall
        width: parent.width * 0.9
        height: width * 0.6
        fillMode: Image.PreserveAspectFit
        source: "../images/cover-gauge.png"
        opacity: 0.18
    }

    Column {
        x: Theme.paddingLarge
        y: Theme.paddingLarge
        width: parent.width - 2 * x
        spacing: Theme.paddingSmall

        Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            truncationMode: TruncationMode.Fade
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.highlightColor
            text: "BMI Tracker"
        }

        Item { width: 1; height: Theme.paddingMedium }

        Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: Theme.fontSizeExtraSmall
            color: Theme.secondaryColor
            text: cover.latest ? "Latest weight" : "No weights yet"
        }
        Label {
            width: parent.width
            visible: !!cover.latest
            horizontalAlignment: Text.AlignHCenter
            fontSizeMode: Text.HorizontalFit
            font.pixelSize: Theme.fontSizeExtraLarge
            text: cover.latestWeightText
        }
        Label {
            width: parent.width
            visible: !!cover.latest
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: Theme.fontSizeExtraSmall
            color: Theme.secondaryColor
            text: cover.latestDateText
        }
        Label {
            width: parent.width
            visible: !cover.latest && cover.store !== null && cover.store.hasProfile
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            font.pixelSize: Theme.fontSizeExtraSmall
            color: Theme.secondaryColor
            text: "Tap + to add one"
        }
    }

    CoverActionList {
        enabled: cover.store !== null && cover.store.hasProfile
        CoverAction {
            iconSource: "image://theme/icon-cover-new"
            onTriggered: cover.addRequested()
        }
    }
}
