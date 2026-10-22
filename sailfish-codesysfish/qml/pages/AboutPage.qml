import QtQuick 2.0
import Sailfish.Silica 1.0
import "../js/about.js" as About

Page {
    id: page

    readonly property string author: About.AUTHOR
    readonly property string version: About.VERSION

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
                title: "About CodeSysFish"
                description: "Version " + page.version
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                color: Theme.highlightColor
                text: "CodeSysFish lets you write IEC 61131-3 Structured Text on your phone, the way " +
                      "CODESYS writes it, and run it like a PLC: it compiles the code, runs PLC_PRG " +
                      "cycle after cycle, and shows every variable live, so you can watch timers run " +
                      "and flip inputs by hand."
            }

            SectionHeader { text: "What it runs" }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryHighlightColor
                text: "PROGRAMs, FUNCTIONs and FUNCTION_BLOCKs; all the elementary types, arrays, " +
                      "structs and enums; IF, CASE, FOR, WHILE and REPEAT; the standard functions and " +
                      "conversions; TON, TOF, TP, R_TRIG, F_TRIG, CTU, CTD, CTUD, SR and RS. " +
                      "The ST reference in the menu has the details."
            }

            SectionHeader { text: "Disclaimers" }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryHighlightColor
                text: "CodeSysFish is an independent app for learning and trying out Structured Text. " +
                      "It isn't made by or affiliated with CODESYS GmbH, and CODESYS is their trademark. " +
                      "It doesn't open CODESYS projects or connect to real PLCs, and it is no replacement " +
                      "for testing on real hardware: don't rely on it for anything that controls machines."
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryHighlightColor
                text: "This app has been created using AI generated code (Claude code)."
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryHighlightColor
                text: "Your projects stay on your phone. The app has no account, tracking or network use."
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
                onClicked: page.openLink(About.OPENREPOS_URL)
            }
        }
    }
}
