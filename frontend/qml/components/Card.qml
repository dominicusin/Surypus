import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: card
    property string title: ""

    color: "#FFFFFF"
    radius: 8
    border.color: "#E0E0E0"
    border.width: 1

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        Label {
            text: card.title
            font.pixelSize: 16
            font.bold: true
            color: "#212121"
            visible: card.title.length > 0
        }

        Rectangle {
            height: 1
            color: "#E0E0E0"
            Layout.fillWidth: true
            visible: card.title.length > 0
        }

        Item { Layout.fillWidth: true; Layout.fillHeight: true }
    }

    default property alias content: contentArea.children

    Item {
        id: contentArea
        anchors.fill: parent
        anchors.topMargin: title.length > 0 ? 60 : 16
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.bottomMargin: 16
    }
}
