import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

// ============================================================================
// REUSABLE QML COMPONENTS
// ============================================================================

// --------------------------------------
// StatCard - Statistics Card Widget
// --------------------------------------
Rectangle {
    property string title: ""
    property string value: ""
    property string icon: ""
    property color color: "#1976D2"
    property int badge: 0
    signal clicked()
    
    width: 180
    height: 120
    radius: 8
    color: "white"
    border.width: 1
    border.color: "#E0E0E0"
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        
        RowLayout {
            Image {
                source: icon
                width: 28
                height: 28
                fillMode: Image.PreserveAspectFit
            }
            Item { Layout.fillWidth: true }
            Badge {
                visible: badge > 0
                text: badge
            }
        }
        
        Item { Layout.fillHeight: true }
        
        Label {
            text: value
            font.pixelSize: 24
            font.bold: true
            color: color
        }
        
        Label {
            text: title
            font.pixelSize: 12
            color: "#757575"
        }
    }
    
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: parent.clicked()
    }
}

// --------------------------------------
// Card - Content Card Widget
// --------------------------------------
Rectangle {
    property string title: ""
    property bool showHeader: true
    
    radius: 8
    color: "white"
    border.width: 1
    border.color: "#E0E0E0"
    
    ColumnLayout {
        anchors.fill: parent
        
        // Header
        Rectangle {
            visible: showHeader
            height: 40
            width: parent.width
            radius: 8
            color: "#FAFAFA"
            
            Label {
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: title
                font.pixelSize: 14
                font.bold: true
                color: "#212121"
            }
            
            RowLayout {
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        
        // Content
        Loader {
            id: contentLoader
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 8
        }
    }
}

// --------------------------------------
// NavItem - Navigation Item
// --------------------------------------
ItemDelegate {
    id: navItem
    height: 48
    width: parent.width
    
    property int badge: 0
    
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        
        Image {
            source: model.icon || "qrc:/icons/blank.png"
            width: 24
            height: 24
        }
        
        Label {
            text: model.title || title
            font.pixelSize: 14
            color: "#212121"
        }
        
        Item { Layout.fillWidth: true }
        
        Badge {
            visible: model.badge > 0
            text: model.badge
        }
    }
    
    background: Rectangle {
        color: navItem.pressed ? "#E3F2FD" : (navItem.hovered ? "#F5F5F5" : "transparent")
    }
}

// --------------------------------------
// TaskDelegate - Task List Item
// --------------------------------------
Rectangle {
    property string taskTitle: ""
    property string taskPriority: "normal"
    property string taskDueDate: ""
    property string taskStatus: "pending"
    
    height: 60
    width: parent.width
    color: "white"
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        
        Label {
            text: taskTitle
            font.pixelSize: 13
            color: "#212121"
            elide: Text.ElideRight
        }
        
        RowLayout {
            Label {
                text: "Приоритет: " + taskPriority
                font.pixelSize: 11
                color: "#757575"
            }
            Label { text: " | "; color: "#BDBDBD" }
            Label {
                text: "Срок: " + taskDueDate
                font.pixelSize: 11
                color: "#757575"
            }
            Label { text: " | "; color: "#BDBDBD" }
            StatusBadge { status: taskStatus }
        }
    }
    
    Rectangle {
        height: 1
        width: parent.width
        color: "#EEEEEE"
        anchors.bottom: parent.bottom
    }
}

// --------------------------------------
// Badge - Notification Badge
// --------------------------------------
Rectangle {
    property string text: "0"
    property color bgColor: "#F44336"
    
    visible: true
    width: 20
    height: 20
    radius: 10
    color: bgColor
    
    Label {
        anchors.centerIn: parent
        text: parent.text
        font.pixelSize: 10
        font.bold: true
        color: "white"
    }
}

// --------------------------------------
// StatusBadge - Status Indicator
// --------------------------------------
Rectangle {
    property string status: "active"
    
    height: 20
    radius: 4
    color: {
        switch(status) {
            case "active": return "#4CAF50";
            case "completed": return "#2196F3";
            case "pending": return "#FFC107";
            case "draft": return "#9E9E9E";
            case "cancelled": return "#F44336";
            case "failed": return "#F44336";
            default: return "#9E9E9E";
        }
    }
    
    Label {
        anchors.centerIn: parent
        text: status
        font.pixelSize: 10
        color: "white"
    }
}

// --------------------------------------
// QuickActionButton - Quick Action
// --------------------------------------
ColumnLayout {
    property string icon: ""
    property string label: ""
    signal clicked()
    
    width: 100
    height: 70
    
    Button {
        icon.source: icon
        icon.width: 32
        icon.height: 32
        width: 60
        height: 45
        anchors.horizontalCenter: parent.horizontalCenter
        onClicked: parent.clicked()
    }
    
    Label {
        text: label
        font.pixelSize: 11
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
    }
}

// --------------------------------------
// LocationCard - Warehouse Card
// --------------------------------------
Card {
    property string locationName: ""
    property string locationType: ""
    property string locationAddress: ""
    property int stockCount: 0
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        
        RowLayout {
            Image {
                source: locationType === "warehouse" ? "qrc:/icons/warehouse.png" : "qrc:/icons/shop.png"
                width: 32
                height: 32
            }
            Column {
                Label {
                    text: locationName
                    font.pixelSize: 14
                    font.bold: true
                }
                Label {
                    text: locationType === "warehouse" ? "Склад" : "Магазин"
                    font.pixelSize: 11
                    color: "#757575"
                }
            }
        }
        
        Item { Layout.fillHeight: true }
        
        Label {
            text: locationAddress
            font.pixelSize: 11
            color: "#757575"
            wrapMode: Text.WordWrap
        }
        
        Label {
            text: "Товаров: " + stockCount
            font.pixelSize: 12
            color: "#1976D2"
        }
    }
}

// --------------------------------------
// ReportTemplateCard - Report Template
// --------------------------------------
Card {
    property string reportName: ""
    property string reportType: ""
    property string reportIcon: ""
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        
        Image {
            source: reportIcon
            width: 40
            height: 40
        }
        
        Label {
            text: reportName
            font.pixelSize: 12
            font.bold: true
            wrapMode: Text.WordWrap
        }
        
        Label {
            text: reportType
            font.pixelSize: 10
            color: "#757575"
        }
        
        Item { Layout.fillHeight: true }
        
        Button {
            text: "Сформировать"
            width: parent.width
            height: 28
        }
    }
}

// --------------------------------------
// KanbanColumn - Kanban Board Column
// --------------------------------------
Card {
    property string title: ""
    property color columnColor: "#1976D2"
    property var model: ListModel {}
    
    width: 280
    
    ColumnLayout {
        anchors.fill: parent
        
        // Header
        Rectangle {
            height: 40
            width: parent.width
            color: columnColor
            
            Label {
                anchors.centerIn: parent
                text: title
                font.bold: true
                color: "white"
            }
        }
        
        // Tasks
        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: parent.model
            delegate: KanbanTask {}
        }
    }
}

// --------------------------------------
// KanbanTask - Kanban Task Card
// --------------------------------------
Rectangle {
    property string taskName: ""
    property int taskPriority: 5
    
    height: 80
    radius: 4
    color: "white"
    border.width: 1
    border.color: "#E0E0E0"
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        
        Label {
            text: taskName
            font.pixelSize: 12
            wrapMode: Text.WordWrap
        }
        
        Item { Layout.fillHeight: true }
        
        RowLayout {
            PriorityIndicator { priority: taskPriority }
            Item { Layout.fillWidth: true }
            Label {
                text: "👤"
                font.pixelSize: 10
            }
        }
    }
}

// --------------------------------------
// PriorityIndicator - Priority Badge
// --------------------------------------
Rectangle {
    property int priority: 5
    
    width: 24
    height: 16
    radius: 4
    color: {
        if (priority >= 9) return "#F44336";
        if (priority >= 7) return "#FF9800";
        if (priority >= 5) return "#FFC107";
        return "#4CAF50";
    }
    
    Label {
        anchors.centerIn: parent
        text: priority
        font.pixelSize: 9
        color: "white"
    }
}

// --------------------------------------
// Paginator - Page Navigation
// --------------------------------------
RowLayout {
    property int currentPage: 1
    property int totalPages: 1
    property int itemsPerPage: 50
    signal pageChanged(int page)
    
    Label {
        text: "Страница " + currentPage + " из " + totalPages
        font.pixelSize: 12
    }
    
    Item { Layout.fillWidth: true }
    
    Button {
        text: "◀ Предыдущая"
        enabled: currentPage > 1
        onClicked: pageChanged(currentPage - 1)
    }
    
    Button {
        text: "Следующая ▶"
        enabled: currentPage < totalPages
        onClicked: pageChanged(currentPage + 1)
    }
}

// --------------------------------------
// FilterPanel - Filter Controls
// --------------------------------------
Rectangle {
    height: 50
    color: "#F5F5F5"
    border.width: 1
    border.color: "#E0E0E0"
    
    RowLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8
        
        ComboBox {
            width: 140
            model: ["Статус", "Активные", "Неактивные"]
        }
        ComboBox {
            width: 140
            model: ["Тип", "Все", "Юр. лицо", "Физ. лицо"]
        }
        DateField { width: 120; placeholderText: "С" }
        DateField { width: 120; placeholderText: "По" }
        
        Button {
            text: "🔍 Применить"
            onClicked: applyFilters()
        }
        Button {
            text: "Сбросить"
            onClicked: resetFilters()
        }
    }
}

// --------------------------------------
// DateField - Date Picker Field
// --------------------------------------
TextField {
    property string placeholderText: "Дата"
    width: 100
    
    MouseArea {
        anchors.fill: parent
        onClicked: datePicker.open()
    }
    
    Popup {
        id: datePicker
        DatePicker {
            onDateSelected: {
                text = date
                datePicker.close()
            }
        }
    }
}

// --------------------------------------
// DatePicker - Date Picker Dialog
// --------------------------------------
Rectangle {
    property date selectedDate: new Date()
    
    width: 250
    height: 300
    color: "white"
    border.width: 1
    border.color: "#E0E0E0"
    
    ColumnLayout {
        anchors.fill: parent
        
        // Header
        RowLayout {
            Button { text: "◀"; onClicked: prevMonth() }
            Label { text: currentMonthName; font.bold: true; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter }
            Button { text: "▶"; onClicked: nextMonth() }
        }
        
        // Days header
        RowLayout {
            Label { text: "Пн"; font.size: 10; Layout.fillWidth: true }
            Label { text: "Вт"; font.size: 10; Layout.fillWidth: true }
            Label { text: "Ср"; font.size: 10; Layout.fillWidth: true }
            Label { text: "Чт"; font.size: 10; Layout.fillWidth: true }
            Label { text: "Пт"; font.size: 10; Layout.fillWidth: true }
            Label { text: "Сб"; font.size: 10; Layout.fillWidth: true; color: "red" }
            Label { text: "Вс"; font.size: 10; Layout.fillWidth: true; color: "red" }
        }
        
        // Days grid
        Grid {
            columns: 7
            rows: 6
            spacing: 2
        }
    }
}

// --------------------------------------
// LoadingOverlay - Loading Indicator
// --------------------------------------
Rectangle {
    property string message: "Загрузка..."
    property bool visible: false
    
    anchors.fill: parent
    color: "#80000000"
    visible: visible
    
    ColumnLayout {
        anchors.centerIn: parent
        
        BusyIndicator {
            running: parent.visible
            width: 50
            height: 50
        }
        
        Label {
            text: message
            color: "white"
            font.pixelSize: 14
        }
    }
}

// --------------------------------------
// ConfirmDialog - Confirmation Dialog
// --------------------------------------
Dialog {
    id: confirmDialog
    property string message: "Вы уверены?"
    property bool accepted: false
    
    ColumnLayout {
        Label { text: message }
        RowLayout {
            Button {
                text: "Отмена"
                onClicked: {
                    accepted = false
                    confirmDialog.close()
                }
            }
            Button {
                text: "Подтвердить"
                onClicked: {
                    accepted = true
                    confirmDialog.close()
                }
            }
        }
    }
}

// --------------------------------------
// NotificationItem - Notification List Item
// --------------------------------------
Rectangle {
    property string notifTitle: ""
    property string notifText: ""
    property string notifTime: ""
    property bool notifRead: false
    
    height: 60
    color: notifRead ? "white" : "#E3F2FD"
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        
        Label {
            text: notifTitle
            font.bold: !notifRead
            font.size: 12
        }
        Label {
            text: notifText
            font.size: 11
            color: "#757575"
        }
        Label {
            text: notifTime
            font.size: 10
            color: "#9E9E9E"
        }
    }
}

// --------------------------------------
// FormField - Form Input Field
// --------------------------------------
ColumnLayout {
    property string label: ""
    property string value: ""
    property bool readOnly: false
    property bool required: false
    property string errorText: ""
    
    spacing: 4
    
    RowLayout {
        Label {
            text: label + (required ? " *" : "")
            font.size: 12
            color: "#757575"
        }
        if (errorText !== "") {
            Label {
                text: errorText
                font.size: 10
                color: "#F44336"
            }
        }
    }
    
    TextField {
        text: value
        readOnly: readOnly
        Layout.fillWidth: true
    }
}

// --------------------------------------
// SearchField - Search Input
// --------------------------------------
TextField {
    id: searchField
    property string placeholder: "Поиск..."
    width: 250
    
    leftPadding: 36
    
    Rectangle {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 24
        height: 24
        Image {
            source: "qrc:/icons/search.png"
            width: 16
            height: 16
            anchors.centerIn: parent
        }
    }
}