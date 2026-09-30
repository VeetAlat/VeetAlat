import QtQuick 2.0
import Sailfish.Silica 1.0
import "../js/rss.js" as Rss

// One article in the list. The first ("hero") gets a big picture on top,
// like the front page of yle.fi; the rest a thumbnail on the right.
ListItem {
    id: item

    property var article
    property bool hero: false
    property real now: Date.now()

    readonly property bool hasImage: article.image !== "" && picture.status !== Image.Error

    contentHeight: column.height + 2 * Theme.paddingMedium

    Column {
        id: column
        y: Theme.paddingMedium
        x: Theme.horizontalPageMargin
        width: parent.width - 2 * x
        spacing: Theme.paddingSmall

        Image {
            id: heroPicture
            visible: item.hero && item.hasImage
            width: parent.width
            height: visible ? width * 9 / 16 : 0
            fillMode: Image.PreserveAspectCrop
            clip: true
            asynchronous: true
            sourceSize.width: width
            source: item.hero ? item.article.image : ""
        }

        Item {
            width: parent.width
            height: Math.max(textColumn.height, thumb.visible ? thumb.height : 0)

            Column {
                id: textColumn
                width: parent.width - (thumb.visible ? thumb.width + Theme.paddingMedium : 0)
                spacing: Theme.paddingSmall / 2

                Label {
                    width: parent.width
                    wrapMode: Text.Wrap
                    maximumLineCount: 4
                    elide: Text.ElideRight
                    font.pixelSize: item.hero ? Theme.fontSizeLarge : Theme.fontSizeMedium
                    color: item.highlighted ? Theme.highlightColor : Theme.primaryColor
                    textFormat: Text.PlainText
                    text: item.article.title
                }
                Label {
                    width: parent.width
                    visible: item.hero && item.article.summary !== ""
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.secondaryColor
                    textFormat: Text.PlainText
                    text: item.article.summary
                }
                Label {
                    width: parent.width
                    truncationMode: TruncationMode.Fade
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: Theme.secondaryHighlightColor
                    text: [Rss.relativeTime(item.article.date, item.now),
                           item.article.categories.length > 0 ? item.article.categories[0] : ""]
                          .filter(function(s) { return s }).join(" · ")
                }
            }

            Image {
                id: thumb
                anchors.right: parent.right
                visible: !item.hero && item.hasImage
                width: Theme.itemSizeExtraLarge
                height: width * 3 / 4
                fillMode: Image.PreserveAspectCrop
                clip: true
                asynchronous: true
                sourceSize.width: width
                source: item.hero ? "" : item.article.image
            }
        }
    }

    // The picture whose status decides hasImage.
    readonly property Image picture: hero ? heroPicture : thumb
}
