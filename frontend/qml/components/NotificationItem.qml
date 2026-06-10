import QtQuick 2.15
import QtQuick.Controls 2.15

ItemDelegate {
    id: notificationItem
    width: parent.width

    contentItem: Column {
        spacing: 2
        Label {
            text: model.title
            font.pixelSize: 13
            font.bold: true
            color: "#212121"
        }
        Label {
            text: model.text
            font.pixelSize: 12
            color: "#757575"
        }
        Label {
            text: model.time
            font.pixelSize: 10
            color: "#9E9E9E"
        }
    }
}
