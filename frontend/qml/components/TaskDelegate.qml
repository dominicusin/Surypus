import QtQuick 2.15
import QtQuick.Controls 2.15

ItemDelegate {
    id: taskDelegate
    width: parent.width

    contentItem: Column {
        spacing: 4
        Label {
            text: model.taskTitle
            font.pixelSize: 14
            font.bold: true
            color: "#212121"
        }
        Row {
            spacing: 8
            Label { text: model.taskPriority; font.pixelSize: 11; color: "#F44336" }
            Label { text: model.taskDueDate; font.pixelSize: 11; color: "#757575" }
            Label { text: model.taskStatus; font.pixelSize: 11; color: "#1976D2" }
        }
    }
}
