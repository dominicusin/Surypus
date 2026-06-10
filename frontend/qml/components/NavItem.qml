import QtQuick 2.15
import QtQuick.Controls 2.15

Rectangle {
    id: navItem
    property string title: ""
    property string page: ""
    property int badge: 0

    height: 48
    color: mouseArea.containsMouse ? "#F5F5F5" : "transparent"

    signal clicked()

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: navItem.clicked()
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 12

        Label {
            text: navItem.title
            font.pixelSize: 14
            color: "#212121"
            Layout.fillWidth: true
        }

        Rectangle {
            width: 20
            height: 20
            radius: 10
            color: "#F44336"
            visible: navItem.badge > 0
            Layout.alignment: Qt.AlignRight

            Label {
                anchors.centerIn: parent
                text: navItem.badge.toString()
                font.pixelSize: 10
                color: "white"
                font.bold: true
            }
        }
    }
}
