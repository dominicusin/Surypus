import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: statCard
    property string title: ""
    property string value: ""
    property string icon: ""
    property color color: "#1976D2"

    width: 200
    height: 120
    color: "#FFFFFF"
    radius: 8
    border.color: "#E0E0E0"
    border.width: 1

    signal clicked()

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: statCard.clicked()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 8

        Label {
            text: statCard.title
            font.pixelSize: 12
            color: "#757575"
        }

        Label {
            text: statCard.value
            font.pixelSize: 28
            font.bold: true
            color: statCard.color
        }
    }
}
