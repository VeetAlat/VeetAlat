import QtQuick 2.0
import Sailfish.Silica 1.0
import "../components"
import "../js/bmi.js" as Bmi

// Three states, each with instructions and a button for the next step:
//   1. no profile yet   -> how it works + "Set up profile"
//   2. no weights yet   -> "Add your first weight"
//   3. data             -> BMI, scale, chart, measurements
Page {
    id: page

    property Store store

    allowedOrientations: Orientation.All

    readonly property bool hasProfile: store !== null && store.hasProfile
    readonly property bool hasData: hasProfile && store.entries.length > 0

    function openProfile() {
        pageStack.push(Qt.resolvedUrl("ProfileDialog.qml"), { store: page.store })
    }
    function openAddWeight() {
        pageStack.push(Qt.resolvedUrl("AddEntryDialog.qml"), { store: page.store })
    }

    function genderName(g) {
        switch (g) {
        case "female": return "female"
        case "male": return "male"
        case "other": return "other"
        default: return ""
        }
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        PullDownMenu {
            MenuItem {
                text: "About and disclaimers"
                onClicked: pageStack.push(Qt.resolvedUrl("AboutPage.qml"), { store: page.store })
            }
            MenuItem {
                text: "Edit profile"
                onClicked: page.openProfile()
            }
            MenuItem {
                text: "Add weight"
                enabled: page.hasProfile
                onClicked: page.openAddWeight()
            }
        }

        VerticalScrollDecorator { }

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingMedium

            PageHeader { title: "BMI Tracker" }

            // Never fail silently.
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: page.store !== null && page.store.lastError !== ""
                wrapMode: Text.Wrap
                color: Theme.errorColor
                text: page.store ? page.store.lastError : ""
            }

            // ---- 1. First run --------------------------------------------
            Column {
                width: parent.width
                spacing: Theme.paddingMedium
                visible: !page.hasProfile

                Label {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * x
                    wrapMode: Text.Wrap
                    font.pixelSize: Theme.fontSizeLarge
                    color: Theme.highlightColor
                    text: "Welcome!"
                }
                Instruction {
                    text: "BMI (body mass index) compares your weight with your height. "
                          + "This app works it out and keeps a history for you."
                }
                SectionHeader { text: "How it works" }
                Step {
                    number: 1
                    title: "Set up your profile"
                    explanation: "Your height, plus your age and gender if you like."
                }
                Step {
                    number: 2
                    title: "Add your weight"
                    explanation: "Whenever you weigh yourself, in kilograms or pounds."
                }
                Step {
                    number: 3
                    title: "Follow your BMI"
                    explanation: "On a colour scale and a chart that grows with every weight."
                }
                Button {
                    anchors.horizontalCenter: parent.horizontalCenter
                    preferredWidth: Theme.buttonWidthLarge
                    text: "Set up profile"
                    onClicked: page.openProfile()
                }
            }

            // ---- 2. Profile, no weights yet ----------------------------------
            Column {
                width: parent.width
                spacing: Theme.paddingMedium
                visible: page.hasProfile && !page.hasData

                Instruction {
                    text: "Your profile is saved (height "
                          + Bmi.formatHeight(page.store ? page.store.heightCm : 0,
                                             page.store ? page.store.heightUnit : "cm")
                          + "). Now add your weight to see your BMI."
                }
                Button {
                    anchors.horizontalCenter: parent.horizontalCenter
                    preferredWidth: Theme.buttonWidthLarge
                    text: "Add your first weight"
                    onClicked: page.openAddWeight()
                }
                Button {
                    anchors.horizontalCenter: parent.horizontalCenter
                    preferredWidth: Theme.buttonWidthLarge
                    text: "Edit profile"
                    onClicked: page.openProfile()
                }
            }

            // ---- 3. Data ----------------------------------------------------
            Column {
                width: parent.width
                spacing: Theme.paddingMedium
                visible: page.hasData

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    font.pixelSize: Theme.fontSizeHuge * 1.4
                    color: Theme.highlightColor
                    text: Bmi.formatBmi(page.store ? page.store.currentBmi : NaN)
                }
                CategoryLabel {
                    anchors.horizontalCenter: parent.horizontalCenter
                    category: page.store ? page.store.currentCategory : null
                    font.pixelSize: Theme.fontSizeLarge
                }

                BmiScale {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * x
                    value: page.store ? page.store.currentBmi : NaN
                }

                Instruction {
                    text: "Blue is underweight, green normal, yellow overweight and red obese. "
                          + "The white marker shows your latest BMI."
                }
                Instruction {
                    visible: page.store !== null && !Bmi.isAdult(page.store.age)
                    color: Theme.highlightColor
                    text: "You're under 20: BMI is judged against age- and sex-specific "
                          + "growth charts, so these adult colours are only a rough guide."
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.paddingLarge
                    Button {
                        text: "Add weight"
                        onClicked: page.openAddWeight()
                    }
                    Button {
                        text: "Edit profile"
                        onClicked: page.openProfile()
                    }
                }

                Column {
                    width: parent.width
                    DetailItem {
                        label: "Latest weight"
                        value: page.store && page.store.latest
                               ? Bmi.formatWeight(page.store.latest.weightKg, page.store.weightUnit)
                               : Bmi.MISSING
                    }
                    DetailItem {
                        label: "Height"
                        value: page.store ? Bmi.formatHeight(page.store.heightCm, page.store.heightUnit) : Bmi.MISSING
                    }
                    DetailItem {
                        label: "Normal weight for you"
                        value: page.store ? Bmi.formatRange(Bmi.healthyRange(page.store.heightCm),
                                                             page.store.weightUnit)
                                          : Bmi.MISSING
                    }
                    DetailItem {
                        visible: page.store !== null && (page.store.age > 0 || page.store.gender !== "")
                        label: "Profile"
                        value: page.store
                               ? [page.store.age > 0 ? page.store.age + " years" : "",
                                  page.genderName(page.store.gender)]
                                 .filter(function(s) { return s }).join(", ")
                               : ""
                    }
                }

                SectionHeader { text: "History" }

                BmiChart {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * x
                    entries: page.store ? page.store.entries : []
                    weightUnit: page.store ? page.store.weightUnit : "kg"
                }
                Instruction { text: "Tap or drag across the chart to see a measurement." }

                SectionHeader { text: "Measurements" }
                Instruction { text: "Press and hold a measurement to delete it." }

                // Newest first.
                Repeater {
                    model: page.store ? page.store.entries.slice().reverse() : []
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
                                text: Bmi.formatBmi(modelData.bmi)
                            }
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: Theme.paddingMedium * 1.5
                                height: width
                                radius: width / 2
                                color: Bmi.category(modelData.bmi) ? Bmi.category(modelData.bmi).color : "transparent"
                            }
                        }
                    }
                }
            }
        }
    }
}
