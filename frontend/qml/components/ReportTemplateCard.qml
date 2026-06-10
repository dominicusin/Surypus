import QtQuick 2.15
import QtQuick.Controls 2.15

Rectangle {
    id: reportTemplateCard
    property string name: ""
    property string type: ""
    property string icon: ""

    width: 230
    height: 80
    color: mouseArea.containsMouse ? "#F5F5F5" : "#FFFFFF"
    radius: 8
    border.color: "#E0E0E0"
    border.width: 1

    signal clicked()

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: reportTemplateCard.clicked()
    }

    Label {
        anchors.centerIn: parent
        text: reportTemplateCard.name
        font.pixelSize: 14
        font.bold: true
        color: "#212121"
    }
}
