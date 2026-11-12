import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: page

    readonly property string author: "Valatalo"
    readonly property string version: "0.1.0"

    // Tests set this to see where a tap would go instead of opening the browser.
    property var openLink: function(link) { Qt.openUrlExternally(link) }

    allowedOrientations: Orientation.All

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge * 2

        VerticalScrollDecorator { }

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingMedium

            PageHeader {
                title: "About VeetPatched"
                description: "Version " + page.version
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                color: Theme.highlightColor
                text: "VeetPatched puts small changes into Sailfish OS's own software, and takes them " +
                      "out again. The app asks; a small helper installed with it does the change as root, " +
                      "only for the patches that come with VeetPatched, and keeps the original file to put back."
            }

            SectionHeader { text: "If something goes wrong" }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryHighlightColor
                text: "To take every patch out, in the Terminal:\n" +
                      "devel-su /usr/libexec/veetpatched/veetpatched-helper unapply-all\n" +
                      "then restart the phone. Uninstalling VeetPatched does the same."
            }

            SectionHeader { text: "Disclaimers" }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryHighlightColor
                text: "Patches change system files: use them at your own risk, and switch them off before " +
                      "updating Sailfish OS. Not made by or affiliated with Jolla. " +
                      "This app has been created using AI generated code (Claude code)."
            }

            SectionHeader { text: "Made by" }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                color: Theme.highlightColor
                text: page.author
            }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                preferredWidth: Theme.buttonWidthLarge
                text: "More from me"
                onClicked: page.openLink("https://openrepos.net/user/19764/programs")
            }
        }
    }
}
