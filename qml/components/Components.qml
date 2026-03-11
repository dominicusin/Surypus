import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

// Stat Card Component
Rectangle {
    property string title: ""
    property string value: ""
    property string icon: ""
    property color color: "#1976D2"
    signal clicked()
    
    width: 250
    height: 120
    radius: 8
    color: "white"
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        
        RowLayout {
            Image {
                source: icon
                width: 32
                height: 32
            }
            Item { Layout.fillWidth: true }
        }
        
        Label {
            text: value
            font.pixelSize: 28
            font.bold: true
            color: color
        }
        
        Label {
            text: title
            font.pixelSize: 14
            color: "#757575"
        }
    }
    
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: parent.clicked()
    }
}

// Card Component
Rectangle {
    property string title: ""
    property var content: null
    
    radius: 8
    color: "white"
    
    ColumnLayout {
        anchors.fill: parent
        
        Label {
            text: title
            font.pixelSize: 16
            font.bold: true
            leftPadding: 16
            topPadding: 16
        }
        
        Item { height: 8 }
        
        Loader {
            sourceComponent: content
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 16
        }
    }
}

// Task Item Delegate
Item {
    height: 60
    width: parent.width
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        
        Label {
            text: modelData.title
            font.pixelSize: 14
        }
        
        RowLayout {
            Label {
                text: modelData.priority
                font.pixelSize: 12
                color: "#757575"
            }
            Label {
                text: " | "
                color: "#757575"
            }
            Label {
                text: modelData.dueDate
                font.pixelSize: 12
                color: "#757575"
            }
        }
    }
    
    Rectangle {
        height: 1
        color: "#E0E0E0"
        anchors.bottom: parent.bottom
    }
}

// Form Field Component
ColumnLayout {
    property string label: ""
    property string value: ""
    property bool readOnly: false
    
    spacing: 4
    
    Label {
        text: label
        font.pixelSize: 12
        color: "#757575"
    }
    
    TextField {
        text: value
        readOnly: readOnly
        Layout.fillWidth: true
    }
}

// Table Paginator
RowLayout {
    property int currentPage: 1
    property int totalPages: 1
    property int itemsPerPage: 50
    
    Label {
        text: "Страница " + currentPage + " из " + totalPages
    }
    
    Item { Layout.fillWidth: true }
    
    Button {
        text: "Предыдущая"
        enabled: currentPage > 1
        onClicked: currentPage--
    }
    
    Button {
        text: "Следующая"
        enabled: currentPage < totalPages
        onClicked: currentPage++
    }
}

// Filter Panel
Rectangle {
    property var filters: []
    
    height: 60
    color: "#F5F5F5"
    
    RowLayout {
        anchors.fill: parent
        anchors.margins: 8
        
        ComboBox {
            label: "Статус"
            model: ["Все", "Активные", "Неактивные"]
        }
        
        ComboBox {
            label: "Тип"
            model: ["Все", "Юр. лицо", "Физ. лицо", "ИП"]
        }
        
        DatePicker {
            label: "С"
        }
        
        DatePicker {
            label: "По"
        }
        
        Button {
            text: "Применить"
            onClicked: applyFilters()
        }
        
        Button {
            text: "Сбросить"
            onClicked: resetFilters()
        }
    }
}

// Loading Indicator
Item {
    visible: loading
    
    Rectangle {
        anchors.centerIn: parent
        width: 50
        height: 50
        radius: 25
        color: "#1976D2"
        opacity: 0.8
        
        NumberAnimation on rotation {
            from: 0
            to: 360
            duration: 1000
            loops: Animation.Infinite
        }
    }
}

// Notification Badge
Rectangle {
    property int count: 0
    
    visible: count > 0
    width: 20
    height: 20
    radius: 10
    color: "#FF5722"
    
    Label {
        anchors.centerIn: parent
        text: count > 99 ? "99+" : count
        font.pixelSize: 10
        color: "white"
    }
}

// Confirm Dialog
Dialog {
    id: confirmDialog
    property string message: "Вы уверены?"
    
    ColumnLayout {
        Label { text: message }
        RowLayout {
            Button {
                text: "Отмена"
                onClicked: confirmDialog.close()
            }
            Button {
                text: "Подтвердить"
                onClicked: {
                    confirmDialog.accepted()
                    confirmDialog.close()
                }
            }
        }
    }
}
