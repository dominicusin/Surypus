import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: kanbanColumn
    property string title: ""
    property color color: "#1976D2"
    property var model: ListModel {}

    Layout.fillWidth: true
    Layout.fillHeight: true
    color: "#FAFAFA"
    radius: 8

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        Rectangle {
            height: 32
            radius: 4
            color: kanbanColumn.color
            Layout.fillWidth: true

            Label {
                anchors.centerIn: parent
                text: kanbanColumn.title
                font.pixelSize: 13
                font.bold: true
                color: "white"
            }
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: kanbanColumn.model
            delegate: Rectangle {
                width: parent.width
                height: 60
                color: "#FFFFFF"
                radius: 4
                border.color: "#E0E0E0"
                border.width: 1
                Label {
                    anchors.centerIn: parent
                    text: "Task"
                    font.pixelSize: 12
                }
            }
        }
    }
}
