import QtQuick 2.0
import Sailfish.Silica 1.0
import "../components"

// Every category as a big button, two per row.
Page {
    id: page

    property NewsStore news

    allowedOrientations: Orientation.All

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        VerticalScrollDecorator { }

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingLarge

            PageHeader { title: "Categories" }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryHighlightColor
                text: "Tap a category to see its headlines. Pääuutiset are the top "
                      + "stories from Yle's front page."
            }

            Grid {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                columns: page.isLandscape ? 3 : 2
                spacing: Theme.paddingMedium

                Repeater {
                    model: page.news ? page.news.categories : []
                    delegate: CategoryButton {
                        width: (parent.width - (parent.columns - 1) * parent.spacing) / parent.columns
                        text: modelData.name
                        subtitle: modelData.english
                        selected: modelData.key === page.news.categoryKey
                        onClicked: {
                            page.news.select(modelData.key)
                            pageStack.pop()
                        }
                    }
                }
            }
        }
    }
}
