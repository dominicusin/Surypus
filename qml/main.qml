import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15

ApplicationWindow {
    id: root
    width: 1280
    height: 800
    minimumWidth: 1024
    minimumHeight: 600
    visible: true
    title: "Surypus ERP/CRM"
    
    // Theme colors
    readonly property color primaryColor: "#1976D2"
    readonly property color secondaryColor: "#424242"
    readonly property color accentColor: "#FF5722"
    readonly property color backgroundColor: "#FAFAFA"
    readonly property color surfaceColor: "#FFFFFF"
    readonly property color textPrimary: "#212121"
    readonly property color textSecondary: "#757575"
    readonly property color errorColor: "#D32F2F"
    readonly property color successColor: "#388E3C"
    
    // Header
    header: ToolBar {
        id: headerBar
        height: 56
        background: Rectangle { color: primaryColor }
        
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            
            // Logo/Title
            Label {
                text: "Surypus ERP"
                font.pixelSize: 20
                font.bold: true
                color: "white"
            }
            
            Item { LayoutLayout.fillWidth: true }
            
            // Search
            TextField {
                id: searchField
                placeholderText: "Поиск..."
                width: 250
                background: Rectangle {
                    radius: 4
                    color: "white"
                }
            }
            
            // User menu
            Menu {
                id: userMenu
                MenuItem {
                    text: "Профиль"
                    onTriggered: profileDialog.open()
                }
                MenuItem {
                    text: "Настройки"
                    onTriggered: settingsDialog.open()
                }
                MenuSeparator {}
                MenuItem {
                    text: "Выход"
                    onTriggered: logout()
                }
            }
            
            Button {
                text: "Администратор ▼"
                flat: true
                textColor: "white"
                onClicked: userMenu.open()
            }
        }
    }
    
    // Drawer - Navigation
    Drawer {
        id: drawer
        width: 280
        height: root.height
        background: surfaceColor
        
        ColumnLayout {
            anchors.fill: parent
            spacing: 0
            
            // User info
            Rectangle {
                height: 100
                width: parent.width
                color: primaryColor
                
                Column {
                    anchors.centerIn: parent
                    Label {
                        text: "Администратор"
                        font.pixelSize: 16
                        font.bold: true
                        color: "white"
                    }
                    Label {
                        text: "admin@surypus.local"
                        font.pixelSize: 12
                        color: "white"
                        opacity: 0.8
                    }
                }
            }
            
            // Navigation menu
            ListView {
                id: navList
                Layout.fillWidth: true
                Layout.fillHeight: true
                model: navModel
                
                delegate: ItemDelegate {
                    width: parent.width
                    height: 48
                    text: modelData.title
                    leftPadding: 16
                    icon.source: modelData.icon
                    
                    onClicked: {
                        navList.currentIndex = index
                        stackView.push(modelData.page)
                        drawer.close()
                    }
                }
            }
        }
    }
    
    // Main content
    StackView {
        id: stackView
        anchors.fill: parent
        initialItem: dashboardPage
    }
    
    // Navigation model
    ListModel {
        id: navModel
        ListElement {
            title: "Главная"
            icon: "qrc:/icons/home.png"
            page: "Dashboard.qml"
        }
        ListElement {
            title: "Контрагенты"
            icon: "qrc:/icons/people.png"
            page: "PersonsPage.qml"
        }
        ListElement {
            title: "Товары"
            icon: "qrc:/icons/goods.png"
            page: "GoodsPage.qml"
        }
        ListElement {
            title: "Склады"
            icon: "qrc:/icons/warehouse.png"
            page: "LocationsPage.qml"
        }
        ListElement {
            title: "Документы"
            icon: "qrc:/icons/document.png"
            page: "BillsPage.qml"
        }
        ListElement {
            title: "Складской учёт"
            icon: "qrc:/icons/stock.png"
            page: "StockPage.qml"
        }
        ListElement {
            title: "Бухгалтерия"
            icon: "qrc:/icons/accounting.png"
            page: "AccountingPage.qml"
        }
        ListElement {
            title: "Зарплата"
            icon: "qrc:/icons/payroll.png"
            page: "PayrollPage.qml"
        }
        ListElement {
            title: "Отчёты"
            icon: "qrc:/icons/reports.png"
            page: "ReportsPage.qml"
        }
        ListElement {
            title: "Задачи"
            icon: "qrc:/icons/tasks.png"
            page: "JobsPage.qml"
        }
    }
    
    // Dashboard Page
    Component {
        id: dashboardPage
        Page {
            title: "Главная"
            background: Rectangle { color: backgroundColor }
            
            GridLayout {
                anchors.fill: parent
                anchors.margins: 24
                columns: 4
                rows: 3
                rowSpacing: 16
                columnSpacing: 16
                
                // Stats cards
                StatCard {
                    title: "Контрагенты"
                    value: "125"
                    icon: "qrc:/icons/people.png"
                    color: "#1976D2"
                    onClicked: stackView.push("PersonsPage.qml")
                }
                StatCard {
                    title: "Товары"
                    value: "1,234"
                    icon: "qrc:/icons/goods.png"
                    color: "#388E3C"
                    onClicked: stackView.push("GoodsPage.qml")
                }
                StatCard {
                    title: "Документы"
                    value: "89"
                    icon: "qrc:/icons/document.png"
                    color: "#FF5722"
                    onClicked: stackView.push("BillsPage.qml")
                }
                StatCard {
                    title: "Задачи"
                    value: "12"
                    icon: "qrc:/icons/tasks.png"
                    color: "#9C27B0"
                    onClicked: stackView.push("JobsPage.qml")
                }
                
                // Recent documents
                Card {
                    Layout.columnSpan: 2
                    Layout.rowSpan: 2
                    title: "Последние документы"
                    
                    TableView {
                        anchors.fill: parent
                        columns: [
                            TableViewColumn { title: "№"; width: 100 },
                            TableViewColumn { title: "Дата"; width: 100 },
                            TableViewColumn { title: "Контрагент"; width: 200 },
                            TableViewColumn { title: "Сумма"; width: 100 },
                            TableViewColumn { title: "Статус"; width: 100 }
                        ]
                        model: recentDocsModel
                    }
                }
                
                // Pending tasks
                Card {
                    Layout.columnSpan: 2
                    Layout.rowSpan: 2
                    title: "Ожидающие задачи"
                    
                    ListView {
                        anchors.fill: parent
                        model: pendingTasksModel
                        delegate: TaskItem {}
                    }
                }
            }
        }
    }
    
    // Persons Page (CRM)
    Component {
        id: personsPage
        Page {
            title: "Контрагенты"
            background: Rectangle { color: backgroundColor }
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 24
                
                // Toolbar
                RowLayout {
                    Button {
                        text: "Добавить"
                        icon.source: "qrc:/icons/add.png"
                        onClicked: personDialog.open()
                    }
                    Button {
                        text: "Фильтр"
                        icon.source: "qrc:/icons/filter.png"
                    }
                    Button {
                        text: "Экспорт"
                        icon.source: "qrc:/icons/export.png"
                    }
                    Item { Layout.fillWidth: true }
                    TextField {
                        id: personSearch
                        placeholderText: "Поиск..."
                        width: 250
                    }
                }
                
                // Table
                TableView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    
                    TableViewColumn { title: "Код"; width: 80 }
                    TableViewColumn { title: "Наименование"; width: 250 }
                    TableViewColumn { title: "ИНН"; width: 120 }
                    TableViewColumn { title: "Тип"; width: 100 }
                    TableViewColumn { title: "Телефон"; width: 130 }
                    TableViewColumn { title: "Email"; width: 180 }
                    TableViewColumn { title: "Статус"; width: 80 }
                    
                    model: personsModel
                    
                    onClicked: personDialog.open()
                }
            }
        }
    }
    
    // Goods Page
    Component {
        id: goodsPage
        Page {
            title: "Товары и услуги"
            background: Rectangle { color: backgroundColor }
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 24
                
                // Toolbar
                RowLayout {
                    Button {
                        text: "Добавить"
                        onClicked: goodsDialog.open()
                    }
                    Button {
                        text: "Группы"
                        onClicked: groupsDialog.open()
                    }
                    Item { Layout.fillWidth: true }
                    ComboBox {
                        width: 150
                        model: ["Все", "Товары", "Услуги"]
                    }
                    TextField {
                        id: goodsSearch
                        placeholderText: "Поиск..."
                        width: 250
                    }
                }
                
                // Table
                TableView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    
                    TableViewColumn { title: "Код"; width: 80 }
                    TableViewColumn { title: "Наименование"; width: 250 }
                    TableViewColumn { title: "Ед.изм"; width: 60 }
                    TableViewColumn { title: "Цена"; width: 100 }
                    TableViewColumn { title: "Остаток"; width: 80 }
                    TableViewColumn { title: "Группа"; width: 120 }
                    TableViewColumn { title: "Статус"; width: 80 }
                    
                    model: goodsModel
                }
            }
        }
    }
    
    // Bills Page
    Component {
        id: billsPage
        Page {
            title: "Документы"
            background: Rectangle { color: backgroundColor }
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 24
                
                // Toolbar
                RowLayout {
                    Button {
                        text: "Создать счёт"
                        onClicked: billDialog.open()
                    }
                    Button {
                        text: "Создать накладную"
                    }
                    Item { Layout.fillWidth: true }
                    DatePicker {
                        id: dateFrom
                    }
                    Label { text: " - " }
                    DatePicker {
                        id: dateTo
                    }
                    Button {
                        text: "Фильтр"
                    }
                }
                
                // Table
                TableView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    
                    TableViewColumn { title: "Номер"; width: 120 }
                    TableViewColumn { title: "Дата"; width: 100 }
                    TableViewColumn { title: "Тип"; width: 80 }
                    TableViewColumn { title: "Контрагент"; width: 200 }
                    TableViewColumn { title: "Сумма"; width: 120 }
                    TableViewColumn { title: "Статус"; width: 100 }
                    
                    model: billsModel
                }
            }
        }
    }
    
    // Dialogs
    Dialog {
        id: personDialog
        title: "Контрагент"
        width: 500
        height: 600
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 16
            
            TextField { label: "Код" }
            TextField { label: "Наименование" }
            TextField { label: "ИНН" }
            TextField { label: "КПП" }
            ComboBox {
                label: "Тип"
                model: ["Юр. лицо", "Физ. лицо", "ИП"]
            }
            TextField { label: "Телефон" }
            TextField { label: "Email" }
            TextField { label: "Адрес" }
            TextArea { label: "Примечание" }
            
            Item { Layout.fillHeight: true }
            
            RowLayout {
                Button {
                    text: "Отмена"
                    onClicked: personDialog.close()
                }
                Item { Layout.fillWidth: true }
                Button {
                    text: "Сохранить"
                    onClicked: personDialog.close()
                }
            }
        }
    }
    
    // Functions
    function logout() {
        // Call Haskell backend
        root.logout()
    }
    
    // Initialize
    Component.onCompleted: {
        drawer.open()
    }
}
