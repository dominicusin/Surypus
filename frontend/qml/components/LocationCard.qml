import QtQuick 2.15
import QtQuick.Controls 2.15

Rectangle {
    id: locationCard
    property string name: ""
    property string type: ""
    property string address: ""
    property string stockCount: ""

    width: 280
    height: 180
    color: mouseArea.containsMouse ? "#F5F5F5" : "#FFFFFF"
    radius: 8
    border.color: "#E0E0E0"
    border.width: 1

    signal clicked()

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: locationCard.clicked()
    }

    Column {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 8

        Label {
            text: locationCard.name
            font.pixelSize: 16
            font.bold: true
            color: "#212121"
        }
        Label {
            text: locationCard.type === "warehouse" ? "🏭 Склад" : "🏪 Магазин"
            font.pixelSize: 12
            color: "#757575"
        }
        Label {
            text: locationCard.address
            font.pixelSize: 12
            color: "#757575"
            wrapMode: Text.WordWrap
        }
        Label {
            text: "Позиций: " + locationCard.stockCount
            font.pixelSize: 12
            color: "#1976D2"
        }
    }
}
