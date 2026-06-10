import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: quickAction
    property string icon: ""
    property string label: ""

    width: 140
    height: 60
    color: mouseArea.containsMouse ? "#F5F5F5" : "#FAFAFA"
    radius: 8
    border.color: "#E0E0E0"
    border.width: 1

    signal clicked()

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: quickAction.clicked()
    }

    RowLayout {
        anchors.centerIn: parent
        spacing: 8

        Image {
            source: quickAction.icon
            width: 24
            height: 24
        }

        Label {
            text: quickAction.label
            font.pixelSize: 12
            color: "#212121"
        }
    }
}
