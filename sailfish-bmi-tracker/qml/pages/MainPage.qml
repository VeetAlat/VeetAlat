import QtQuick 2.0
import Sailfish.Silica 1.0
import "../components"
import "../js/bmi.js" as Bmi

Page {
    id: page

    property Store store

    allowedOrientations: Orientation.All

    readonly property bool ready: store.hasProfile && store.entries.length > 0

    function genderName(g) {
        switch (g) {
        case "female": return "Female"
        case "male": return "Male"
        case "other": return "Other"
        default: return ""
        }
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        PullDownMenu {
            MenuItem {
                text: "Profile and units"
                onClicked: pageStack.push(Qt.resolvedUrl("ProfileDialog.qml"), { store: page.store })
            }
            MenuItem {
                text: "Add weight"
                enabled: page.store.hasProfile
                onClicked: pageStack.push(Qt.resolvedUrl("AddEntryDialog.qml"), { store: page.store })
            }
        }

        ViewPlaceholder {
            enabled: !page.ready
            text: page.store.hasProfile ? "No weights yet" : "Welcome to BMI Tracker"
            hintText: page.store.hasProfile
                      ? "Pull down to add your weight"
                      : "Pull down to enter your height, age and gender"
        }

        VerticalScrollDecorator { }

        Column {
            id: column
            width: parent.width
            visible: page.ready

            PageHeader { title: "BMI Tracker" }

            // Headline: the latest BMI and its category.
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                font.pixelSize: Theme.fontSizeHuge * 1.4
                color: Theme.highlightColor
                text: isNaN(page.store.currentBmi) ? "–" : Bmi.rounded(page.store.currentBmi).toFixed(1)
            }
            CategoryLabel {
                anchors.horizontalCenter: parent.horizontalCenter
                category: page.store.currentCategory
                font.pixelSize: Theme.fontSizeLarge
            }

            Item { width: 1; height: Theme.paddingLarge }

            BmiScale {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                value: page.store.currentBmi
            }

            Item { width: 1; height: Theme.paddingMedium; visible: !Bmi.isAdult(page.store.age) }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: !Bmi.isAdult(page.store.age)
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryHighlightColor
                text: "Under 20, BMI is judged against age- and sex-specific growth "
                      + "charts, so these adult categories are only a rough guide."
            }

            Item { width: 1; height: Theme.paddingMedium }

            DetailItem {
                label: "Weight"
                value: page.store.latest ? Bmi.formatWeight(page.store.latest.weightKg, page.store.weightUnit) : ""
            }
            DetailItem {
                label: "Height"
                value: Bmi.formatHeight(page.store.heightCm, page.store.heightUnit)
            }
            DetailItem {
                label: "Normal weight for you"
                value: Bmi.formatRange(Bmi.healthyRange(page.store.heightCm), page.store.weightUnit)
            }
            DetailItem {
                visible: page.store.age > 0 || page.store.gender !== ""
                label: "Profile"
                value: [page.store.age > 0 ? page.store.age + " years" : "",
                        page.genderName(page.store.gender)].filter(function(s) { return s }).join(", ")
            }

            SectionHeader { text: "History" }

            BmiChart {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                entries: page.store.entries
                weightUnit: page.store.weightUnit
            }

            SectionHeader { text: "Measurements" }

            // Newest first. Long-press to delete.
            Repeater {
                model: page.store.entries.slice().reverse()
                delegate: ListItem {
                    id: item
                    contentHeight: Theme.itemSizeSmall
                    menu: ContextMenu {
                        MenuItem {
                            text: "Delete"
                            onClicked: item.remorseDelete(function() {
                                page.store.removeEntry(modelData.id)
                            })
                        }
                    }

                    Label {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.horizontalPageMargin
                        anchors.verticalCenter: parent.verticalCenter
                        text: Qt.formatDate(page.store.parseIsoDate(modelData.date), Qt.DefaultLocaleShortDate)
                    }
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.secondaryColor
                        text: Bmi.formatWeight(modelData.weightKg, page.store.weightUnit)
                    }
                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.horizontalPageMargin
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.paddingSmall
                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Bmi.rounded(modelData.bmi).toFixed(1)
                        }
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Theme.paddingMedium * 1.5
                            height: width
                            radius: width / 2
                            color: Bmi.category(modelData.bmi).color
                        }
                    }
                }
            }
        }
    }
}
