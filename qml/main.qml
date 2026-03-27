import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Dialogs 1.3
import QtQuick.Window 2.15

// ============================================================================
// MAIN APPLICATION WINDOW
// ============================================================================

ApplicationWindow {
    id: appWindow
    width: 1400
    height: 900
    minimumWidth: 1200
    minimumHeight: 700
    visible: true
    title: "Surypus ERP - Управление предприятием"
    
    // Theme
    readonly property color primaryColor: "#1976D2"
    readonly property color primaryDark: "#1565C0"
    readonly property color primaryLight: "#42A5F5"
    readonly property color secondaryColor: "#FF5722"
    readonly property color backgroundColor: "#F5F5F5"
    readonly property color surfaceColor: "#FFFFFF"
    readonly property color textPrimary: "#212121"
    readonly property color textSecondary: "#757575"
    readonly property color dividerColor: "#E0E0E0"
    readonly property color successColor: "#4CAF50"
    readonly property color warningColor: "#FFC107"
    readonly property color errorColor: "#F44336"
    
    // ========================================
    // HEADER TOOLBAR
    // ========================================
    header: ToolBar {
        height: 64
        background: Rectangle { 
            gradient: Gradient {
                GradientStop { position: 0; color: primaryColor }
                GradientStop { position: 1; color: primaryDark }
            }
        }
        
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            
            // Menu toggle
            ToolButton {
                icon.source: "qrc:/icons/menu.png"
                icon.color: "white"
                onClicked: drawer.visible = !drawer.visible
            }
            
            // Logo
            Label {
                text: "🏢 Surypus ERP"
                font.pixelSize: 22
                font.bold: true
                color: "white"
                leftPadding: 8
            }
            
            Item { Layout.fillWidth: true }
            
            // Global search
            TextField {
                id: globalSearch
                width: 300
                placeholderText: "Быстрый поиск (Ctrl+F)..."
                background: Rectangle {
                    radius: 4
                    color: "white"
                    opacity: 0.95
                }
                Keys.onReturnPressed: executeSearch()
            }
            
            // Notifications
            ToolButton {
                icon.source: "qrc:/icons/bell.png"
                icon.color: "white"
                badge.text: "3"
                badge.visible: true
                onClicked: notificationsPopup.open()
            }
            
            // User menu
            Menu {
                id: userMenu
                MenuItem { text: "👤 Профиль"; onTriggered: profileDialog.open() }
                MenuItem { text: "⚙️ Настройки"; onTriggered: settingsDialog.open() }
                MenuSeparator {}
                MenuItem { text: "❓ Справка"; onTriggered: helpDialog.open() }
                MenuSeparator {}
                MenuItem { text: "🚪 Выход"; onTriggered: logout() }
            }
            
            Button {
                text: "👤 Администратор ▾"
                flat: true
                textColor: "white"
                onClicked: userMenu.open()
            }
        }
    }
    
    // ========================================
    // SIDEBAR NAVIGATION (Drawer)
    // ========================================
    Drawer {
        id: drawer
        width: 280
        height: parent.height
        background: surfaceColor
        
        ColumnLayout {
            anchors.fill: parent
            
            // User panel
            Rectangle {
                height: 100
                width: parent.width
                gradient: Gradient {
                    GradientStop { position: 0; color: primaryColor }
                    GradientStop { position: 1; color: primaryDark }
                }
                
                Column {
                    anchors.centerIn: parent
                    spacing: 4
                    Label {
                        text: userName
                        font.pixelSize: 16
                        font.bold: true
                        color: "white"
                    }
                    Label {
                        text: userEmail
                        font.pixelSize: 12
                        color: "white"
                        opacity: 0.8
                    }
                    Label {
                        text: "Статус: " + userStatus
                        font.pixelSize: 10
                        color: successColor
                    }
                }
            }
            
            // Navigation
            ListView {
                id: navigationView
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                
                model: navigationModel
                delegate: NavItem {
                    onClicked: navigateTo(modelData.page)
                }
            }
        }
    }
    
    // Navigation model
    ListModel {
        id: navigationModel
        ListElement {
            title: "📊 Главная"
            page: "DashboardPage.qml"
            badge: 0
        }
        ListElement {
            title: "👥 Контрагенты"
            page: "PersonsPage.qml"
            badge: 5
        }
        ListElement {
            title: "📦 Товары и услуги"
            page: "GoodsPage.qml"
            badge: 0
        }
        ListElement {
            title: "🏭 Склады"
            page: "LocationsPage.qml"
            badge: 0
        }
        ListElement {
            title: "📋 Документы"
            page: "BillsPage.qml"
            badge: 12
        }
        ListElement {
            title: "📈 Складской учёт"
            page: "StockPage.qml"
            badge: 0
        }
        ListElement {
            title: "💰 Бухгалтерия"
            page: "AccountingPage.qml"
            badge: 0
        }
        ListElement {
            title: "👨‍💼 Зарплата"
            page: "PayrollPage.qml"
            badge: 0
        }
        ListElement {
            title: "📊 Отчёты"
            page: "ReportsPage.qml"
            badge: 0
        }
        ListElement {
            title: "✅ Задачи"
            page: "JobsPage.qml"
            badge: 3
        }
        ListElement {
            title: "⚙️ Настройки"
            page: "SettingsPage.qml"
            badge: 0
        }
    }

    // Dashboard statistics
    property var stats: ({
        persons: "125",
        goods: "1 234",
        bills: "89",
        jobs: "12",
        locations: "5",
        revenue: "2.4M",
        expenses: "1.8M",
        profit: "600K"
    })

    // Recent documents model
    ListModel {
        id: recentDocsModel
        ListElement { number: "INV-2026-089"; date: "27.03.2026"; customer: "ООО ТехноСтрой"; total: "50 000 ₽"; status: "Проведён" }
        ListElement { number: "INV-2026-088"; date: "26.03.2026"; customer: "ИП Иванов"; total: "25 000 ₽"; status: "На утверждении" }
        ListElement { number: "INV-2026-087"; date: "25.03.2026"; customer: "ООО МегаТрейд"; total: "75 000 ₽"; status: "Черновик" }
        ListElement { number: "PL-001"; date: "24.03.2026"; customer: "ООО ТехноСтрой"; total: "50 000 ₽"; status: "Проведён" }
        ListElement { number: "ACT-003"; date: "23.03.2026"; customer: "ИП Петров"; total: "15 000 ₽"; status: "Проведён" }
    }

    // Pending tasks model
    ListModel {
        id: pendingTasksModel
        ListElement { taskTitle: "Отправить отчёт"; taskPriority: "Высокий"; taskDueDate: "28.03.2026"; taskStatus: "Ожидает" }
        ListElement { taskTitle: "Обработать платежи"; taskPriority: "Высокий"; taskDueDate: "27.03.2026"; taskStatus: "В работе" }
        ListElement { taskTitle: "Сформировать накладную"; taskPriority: "Средний"; taskDueDate: "27.03.2026"; taskStatus: "Ожидает" }
    }

    // Persons model
    ListModel {
        id: personsModel
        ListElement { code: "P001"; name: "ООО ТехноСтрой"; inn: "7701234567890"; kpp: "770101001"; type: "Юр. лицо"; phone: "+7 495 123-4567"; email: "info@tehnostroy.ru"; status: "Активен" }
        ListElement { code: "P002"; name: "ИП Иванов И.И."; inn: "7709876543210"; kpp: ""; type: "ИП"; phone: "+7 916 123-4567"; email: "ivanov@mail.ru"; status: "Активен" }
        ListElement { code: "P003"; name: "ООО МегаТрейд"; inn: "7705555555555"; kpp: "770201001"; type: "Юр. лицо"; phone: "+7 495 987-6543"; email: "info@megatrade.ru"; status: "Активен" }
    }

    // Goods model
    ListModel {
        id: goodsModel
        ListElement { code: "G001"; name: "Стройматериалы"; unit: "кг"; price: "100"; quantity: "500"; group: "Стройматериалы"; vatRate: "20"; status: "Активен" }
        ListElement { code: "G002"; name: "Инструменты"; unit: "шт"; price: "250"; quantity: "100"; group: "Инструменты"; vatRate: "20"; status: "Активен" }
        ListElement { code: "G003"; name: "Крепёж"; unit: "кг"; price: "50"; quantity: "1000"; group: "Крепёж"; vatRate: "20"; status: "Активен" }
    }

    // Bills model
    ListModel {
        id: billsModel
        ListElement { number: "INV-2026-089"; date: "27.03.2026"; type: "Счёт"; customer: "ООО ТехноСтрой"; total: "50 000"; vat: "8 333"; location: "Основной"; status: "Проведён"; author: "admin" }
        ListElement { number: "INV-2026-088"; date: "26.03.2026"; type: "Счёт"; customer: "ИП Иванов"; total: "25 000"; vat: "4 167"; location: "Основной"; status: "На утвержд."; author: "admin" }
        ListElement { number: "INV-2026-087"; date: "25.03.2026"; type: "Счёт"; customer: "ООО МегаТрейд"; total: "75 000"; vat: "12 500"; location: "Розничный"; status: "Черновик"; author: "buh" }
    }

    // Locations model
    ListModel {
        id: locationsModel
        ListElement { name: "Основной склад"; type: "warehouse"; address: "г. Москва, ул. Промышленная, д. 10"; stockCount: "850" }
        ListElement { name: "Розничный магазин №1"; type: "shop"; address: "г. Москва, ул. Центральная, д. 25"; stockCount: "320" }
        ListElement { name: "Склад запчастей"; type: "warehouse"; address: "г. Москва, ул. Заводская, д. 5"; stockCount: "64" }
    }

    // Employees model
    ListModel {
        id: employeesModel
        ListElement { tabNum: "001"; name: "Петров А.С."; position: "Директор"; department: "Администрация"; salary: "80 000"; status: "Работает" }
        ListElement { tabNum: "002"; name: "Сидорова Е.П."; position: "Бухгалтер"; department: "Бухгалтерия"; salary: "55 000"; status: "Работает" }
        ListElement { tabNum: "003"; name: "Козлов М.И."; position: "Менеджер"; department: "Продажи"; salary: "45 000"; status: "В отпуске" }
    }

    // Report templates model
    ListModel {
        id: reportTemplatesModel
        ListElement { name: "Продажи"; type: "sales"; icon: "chart" }
        ListElement { name: "Прибыльность"; type: "profitability"; icon: "money" }
        ListElement { name: "Остатки"; type: "stock"; icon: "box" }
        ListElement { name: "Дебиторы"; type: "debtors"; icon: "people" }
    }

    // Notifications model
    ListModel {
        id: notificationsModel
        ListElement { title: "Новый счёт"; text: "Создан счёт INV-2026-090"; time: "10:30" }
        ListElement { title: "Задача выполнена"; text: "Обработаны платежи"; time: "09:15" }
        ListElement { title: "Низкий остаток"; text: "Крепёж: 50 кг"; time: "Вчера" }
    }

    // Accounts model for accounting
    ListModel {
        id: accountsModel
        ListElement { code: "50"; name: "Касса" }
        ListElement { code: "51"; name: "Расчётный счёт" }
        ListElement { code: "60"; name: "Расчёты с поставщиками" }
        ListElement { code: "62"; name: "Расчёты с покупателями" }
        ListElement { code: "41"; name: "Товары" }
    }

    // Pagination properties
    property int personPage: 1
    property int personTotalPages: 5

    // Bill totals
    property string billTotalSum: "150 000"
    property string billTotalVat: "25 000"

    // User info
    property string userName: "Администратор"
    property string userEmail: "admin@surypus.local"
    property string userStatus: "Онлайн"
    property string companyName: "ООО ТехноСтрой"

    // Page state
    property string currentPage: "dashboard"

    // HTTP request function
    function httpRequest(method, path, payload, onSuccess, onError) {
        var xhr = new XMLHttpRequest()
        xhr.open(method, apiBaseUrl + path)
        xhr.setRequestHeader("Content-Type", "application/json")
        if (jwtToken.length > 0) {
            xhr.setRequestHeader("Authorization", "Bearer " + jwtToken)
        }
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status >= 200 && xhr.status < 300) {
                    var parsed = JSON.parse(xhr.responseText)
                    if (parsed.status === "ok" && onSuccess) {
                        onSuccess(parsed)
                    } else if (onError) {
                        onError(xhr.status, parsed)
                    }
                } else if (onError) {
                    onError(xhr.status, xhr.responseText)
                }
            }
        }
        xhr.send(payload ? JSON.stringify(payload) : null)
    }

    // CRUD functions
    function loadPersons() { console.log("Loading persons...") }
    function filterPersons() { console.log("Filtering persons...") }
    function createPerson() { personDialog.open() }
    function editPerson(person) { console.log("Editing:", person); personDialog.open() }
    function savePerson() { console.log("Saving person..."); personDialog.close() }
    function importPersons() { console.log("Importing persons...") }
    function exportPersons() { console.log("Exporting persons...") }

    function createGoods() { goodsDialog.open() }
    function createBill() { billDialog.open() }
    function createInvoice() { console.log("Creating invoice...") }
    function createWaybill() { console.log("Creating waybill...") }
    function createAct() { console.log("Creating act...") }

    function createJob() { console.log("Creating job..."); jobDialog.open() }
    function hireDialog() { console.log("Opening hire dialog..."); employeeDialog.open() }
    function calculatePayroll() { console.log("Calculating payroll...") }
    function paySalary() { console.log("Paying salary...") }

    function showStock() { console.log("Showing stock...") }
    function groupsDialog() { console.log("Opening groups dialog...") }
    function templatesDialog() { console.log("Opening templates dialog...") }
    function openLocationDialog() { locationDialog.open() }
    function openShopDialog() { shopDialog.open() }
    function openJobDialog() { jobDialog.open() }
    function openPaymentDialog() { paymentDialog.open() }
    function openCurrencyDialog() { currencyDialog.open() }
    function openTaxDialog() { taxDialog.open() }
    function openAccountDialog() { accountDialog.open() }
    function openReportScheduleDialog() { reportScheduleDialog.open() }
    function openEmployeeDialog() { employeeDialog.open() }
    
    // Save functions
    function saveLocation() { console.log("Saving location..."); locationDialog.close() }
    function savePayment() { console.log("Saving payment..."); paymentDialog.close() }
    function saveEmployee() { console.log("Saving employee..."); employeeDialog.close() }
    function saveReportSchedule() { console.log("Saving report schedule..."); reportScheduleDialog.close() }
    function saveCurrency() { console.log("Saving currency..."); currencyDialog.close() }
    function saveTax() { console.log("Saving tax..."); taxDialog.close() }
    function saveAccount() { console.log("Saving account..."); accountDialog.close() }
    
    // ========================================
    // MAIN CONTENT AREA
    // ========================================
    StackView {
        id: contentStack
        anchors.fill: parent
        initialItem: dashboardPage
    }
    
    // ========================================
    // DASHBOARD PAGE
    // ========================================
    Component {
        id: dashboardPage
        
        Page {
            id: dashboard
            title: "Главная панель"
            background: Rectangle { color: backgroundColor }
            
            ScrollView {
                anchors.fill: parent
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 24
                    spacing: 20
                    
                    // Stats row
                    RowLayout {
                        spacing: 16
                        
                        StatCard {
                            title: "Контрагенты"
                            value: stats.persons
                            icon: "qrc:/icons/people.png"
                            color: primaryColor
                            onClicked: navigateTo("PersonsPage.qml")
                        }
                        StatCard {
                            title: "Товары"
                            value: stats.goods
                            icon: "qrc:/icons/goods.png"
                            color: successColor
                            onClicked: navigateTo("GoodsPage.qml")
                        }
                        StatCard {
                            title: "Документы"
                            value: stats.bills
                            icon: "qrc:/icons/document.png"
                            color: secondaryColor
                            onClicked: navigateTo("BillsPage.qml")
                        }
                        StatCard {
                            title: "Задачи"
                            value: stats.jobs
                            icon: "qrc:/icons/tasks.png"
                            color: "#9C27B0"
                            onClicked: navigateTo("JobsPage.qml")
                        }
                        StatCard {
                            title: "Склады"
                            value: stats.locations
                            icon: "qrc:/icons/warehouse.png"
                            color: "#FF9800"
                            onClicked: navigateTo("LocationsPage.qml")
                        }
                    }
                    
                    // Charts and tables row
                    RowLayout {
                        spacing: 16
                        Layout.fillWidth: true
                        
                        // Recent documents
                        Card {
                            title: "Последние документы"
                            width: 500
                            height: 350
                            
                            TableView {
                                anchors.fill: parent
                                model: recentDocsModel
                                headerVisible: true
                                
                                TableViewColumn { title: "№"; width: 100; role: "number" }
                                TableViewColumn { title: "Дата"; width: 90; role: "date" }
                                TableViewColumn { title: "Контрагент"; width: 150; role: "customer" }
                                TableViewColumn { title: "Сумма"; width: 80; role: "total" }
                                TableViewColumn { title: "Статус"; width: 70; role: "status" }
                            }
                        }
                        
                        // Pending tasks
                        Card {
                            title: "Ожидающие задачи"
                            width: 400
                            height: 350
                            
                            ListView {
                                anchors.fill: parent
                                model: pendingTasksModel
                                delegate: TaskDelegate {}
                            }
                        }
                    }
                    
                    // Quick actions
                    Card {
                        title: "Быстрые действия"
                        height: 100
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 12
                            
                            QuickActionButton {
                                icon: "qrc:/icons/add_person.png"
                                label: "Новый контрагент"
                                onClicked: createPerson()
                            }
                            QuickActionButton {
                                icon: "qrc:/icons/add_goods.png"
                                label: "Новый товар"
                                onClicked: createGoods()
                            }
                            QuickActionButton {
                                icon: "qrc:/icons/add_bill.png"
                                label: "Новый счёт"
                                onClicked: createBill()
                            }
                            QuickActionButton {
                                icon: "qrc:/icons/add_job.png"
                                label: "Новая задача"
                                onClicked: createJob()
                            }
                        }
                    }
                }
            }
        }
    }
    
    // ========================================
    // PERSONS PAGE (CRM)
    // ========================================
    Component {
        id: personsPage
        Page {
            title: "Контрагенты"
            background: Rectangle { color: backgroundColor }
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 16
                
                // Toolbar
                RowLayout {
                    Button {
                        text: "➕ Добавить"
                        icon.source: "qrc:/icons/add.png"
                        onClicked: personDialog.open()
                    }
                    Button {
                        text: "📥 Импорт"
                        onClicked: importPersons()
                    }
                    Button {
                        text: "📤 Экспорт"
                        onClicked: exportPersons()
                    }
                    Item { Layout.fillWidth: true }
                    
                    // Filters
                    ComboBox {
                        id: personTypeFilter
                        width: 150
                        model: ["Все типы", "Юр. лицо", "Физ. лицо", "ИП"]
                    }
                    ComboBox {
                        id: personStatusFilter
                        width: 150
                        model: ["Все статусы", "Активные", "Неактивные"]
                    }
                    
                    TextField {
                        id: personSearch
                        width: 250
                        placeholderText: "Поиск по наименованию, ИНН..."
                        onTextChanged: filterPersons()
                    }
                }
                
                // Persons table
                Card {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    
                    TableView {
                        id: personsTable
                        anchors.fill: parent
                        model: personsModel
                        headerVisible: true
                        rowHeight: 48
                        
                        TableViewColumn { title: "Код"; width: 80; role: "code" }
                        TableViewColumn { title: "Наименование"; width: 200; role: "name" }
                        TableViewColumn { title: "ИНН"; width: 110; role: "inn" }
                        TableViewColumn { title: "КПП"; width: 90; role: "kpp" }
                        TableViewColumn { title: "Тип"; width: 80; role: "type" }
                        TableViewColumn { title: "Телефон"; width: 120; role: "phone" }
                        TableViewColumn { title: "Email"; width: 160; role: "email" }
                        TableViewColumn { title: "Статус"; width: 80; role: "status" }
                        TableViewColumn { title: "Действия"; width: 100; role: "actions" }
                        
                        onClicked: (row) => editPerson(personsModel.get(row))
                    }
                }
                
                // Paginator
                Paginator {
                    currentPage: personPage
                    totalPages: personTotalPages
                    onPageChanged: loadPersons()
                }
            }
        }
    }
    
    // ========================================
    // GOODS PAGE
    // ========================================
    Component {
        id: goodsPage
        Page {
            title: "Товары и услуги"
            background: Rectangle { color: backgroundColor }
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 16
                
                // Toolbar
                RowLayout {
                    Button { text: "➕ Добавить"; onClicked: goodsDialog.open() }
                    Button { text: "📁 Группы"; onClicked: groupsDialog.open() }
                    Button { text: "📊 Остатки"; onClicked: showStock() }
                    Item { Layout.fillWidth: true }
                    
                    ComboBox {
                        model: ["Все", "Товары", "Услуги", "Продукция"]
                    }
                    ComboBox {
                        model: ["Все группы", "Стройматериалы", "Инструменты"]
                    }
                    
                    TextField {
                        width: 250
                        placeholderText: "Поиск..."
                    }
                }
                
                // Goods table
                Card {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    
                    TableView {
                        anchors.fill: parent
                        model: goodsModel
                        headerVisible: true
                        
                        TableViewColumn { title: "Код"; width: 70; role: "code" }
                        TableViewColumn { title: "Наименование"; width: 220; role: "name" }
                        TableViewColumn { title: "Ед.изм"; width: 60; role: "unit" }
                        TableViewColumn { title: "Цена"; width: 90; role: "price" }
                        TableViewColumn { title: "Остаток"; width: 70; role: "quantity" }
                        TableViewColumn { title: "Группа"; width: 120; role: "group" }
                        TableViewColumn { title: "НДС %"; width: 60; role: "vatRate" }
                        TableViewColumn { title: "Статус"; width: 70; role: "status" }
                    }
                }
            }
        }
    }
    
    // ========================================
    // BILLS PAGE
    // ========================================
    Component {
        id: billsPage
        Page {
            title: "Документы"
            background: Rectangle { color: backgroundColor }
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 16
                
                // Toolbar
                RowLayout {
                    MenuButton {
                        text: "➕ Создать"
                        menu: ContextMenu {
                            MenuItem { text: "Счёт на оплату"; onTriggered: createBill() }
                            MenuItem { text: "Счёт-фактура"; onTriggered: createInvoice() }
                            MenuItem { text: "Товарная накладная"; onTriggered: createWaybill() }
                            MenuItem { text: "Акт выполненных работ"; onTriggered: createAct() }
                        }
                    }
                    Button { text: "📋 Шаблоны"; onClicked: templatesDialog.open() }
                    Item { Layout.fillWidth: true }
                    
                    // Date range
                    Label { text: "Период:" }
                    DateField { id: dateFrom }
                    Label { text: " - " }
                    DateField { id: dateTo }
                    
                    ComboBox {
                        model: ["Все типы", "Счета", "Накладные", "Акты"]
                    }
                    ComboBox {
                        model: ["Все статусы", "Черновик", "На утверждении", "Проведён", "Отменён"]
                    }
                }
                
                // Bills table
                Card {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    
                    TableView {
                        anchors.fill: parent
                        model: billsModel
                        
                        TableViewColumn { title: "Номер"; width: 110; role: "number" }
                        TableViewColumn { title: "Дата"; width: 90; role: "date" }
                        TableViewColumn { title: "Тип"; width: 70; role: "type" }
                        TableViewColumn { title: "Контрагент"; width: 180; role: "customer" }
                        TableViewColumn { title: "Сумма"; width: 100; role: "total" }
                        TableViewColumn { title: "НДС"; width: 80; role: "vat" }
                        TableViewColumn { title: "Склад"; width: 100; role: "location" }
                        TableViewColumn { title: "Статус"; width: 80; role: "status" }
                        TableViewColumn { title: "Автор"; width: 100; role: "author" }
                    }
                }
                
                // Summary
                RowLayout {
                    Label { text: "Итого: " + billTotalSum + " руб." }
                    Label { text: "НДС: " + billTotalVat + " руб." }
                }
            }
        }
    }
    
    // ========================================
    // LOCATIONS PAGE
    // ========================================
    Component {
        id: locationsPage
        Page {
            title: "Склады и магазины"
            background: Rectangle { color: backgroundColor }
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 24
                
                RowLayout {
                    Button { text: "➕ Добавить склад"; onClicked: locationDialog.open() }
                    Button { text: "➕ Добавить магазин"; onClicked: shopDialog.open() }
                }
                
                // Locations grid
                GridView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: locationsModel
                    cellWidth: 300
                    cellHeight: 200
                    
                    delegate: LocationCard {}
                }
            }
        }
    }
    
    // ========================================
    // ACCOUNTING PAGE
    // ========================================
    Component {
        id: accountingPage
        Page {
            title: "Бухгалтерия"
            background: Rectangle { color: backgroundColor }
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 24
                
                // Chart of accounts
                Card {
                    title: "План счетов"
                    Layout.fillWidth: true
                    height: 300
                    
                    TreeView {
                        anchors.fill: parent
                        model: accountsModel
                    }
                }
                
                // Entries
                Card {
                    title: "Журнал проводок"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    
                    TableView {
                        anchors.fill: parent
                        model: entriesModel
                        
                        TableViewColumn { title: "Дата"; width: 90 }
                        TableViewColumn { title: "№"; width: 80 }
                        TableViewColumn { title: "Дебет"; width: 100 }
                        TableViewColumn { title: "Кредит"; width: 100 }
                        TableViewColumn { title: "Сумма"; width: 100 }
                        TableViewColumn { title: "Документ"; width: 150 }
                        TableViewColumn { title: "Содержание"; width: 200 }
                    }
                }
            }
        }
    }
    
    // ========================================
    // PAYROLL PAGE
    // ========================================
    Component {
        id: payrollPage
        Page {
            title: "Зарплата"
            background: Rectangle { color: backgroundColor }
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 24
                
                RowLayout {
                    Button { text: "➕ Приём сотрудника"; onClicked: hireDialog.open() }
                    Button { text: "📄 Начислить зарплату"; onClicked: calculatePayroll() }
                    Button { text: "💸 Выплатить"; onClicked: paySalary() }
                }
                
                // Employees
                Card {
                    title: "Сотрудники"
                    Layout.fillWidth: true
                    height: 300
                    
                    TableView {
                        anchors.fill: parent
                        model: employeesModel
                        
                        TableViewColumn { title: "Таб.№"; width: 60 }
                        TableViewColumn { title: "ФИО"; width: 180 }
                        TableViewColumn { title: "Должность"; width: 140 }
                        TableViewColumn { title: "Отдел"; width: 120 }
                        TableViewColumn { title: "Оклад"; width: 100 }
                        TableViewColumn { title: "Статус"; width: 80 }
                    }
                }
                
                // Payroll journal
                Card {
                    title: "Расчётная ведомость"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    
                    TableView {
                        anchors.fill: parent
                        model: payrollModel
                    }
                }
            }
        }
    }
    
    // ========================================
    // JOBS PAGE
    // ========================================
    Component {
        id: jobsPage
        Page {
            title: "Задачи"
            background: Rectangle { color: backgroundColor }
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 24
                
                RowLayout {
                    Button { text: "➕ Новая задача"; onClicked: jobDialog.open() }
                    ComboBox {
                        model: ["Все", "Мои", "Неназначенные"]
                    }
                }
                
                // Kanban board
                RowLayout {
                    KanbanColumn {
                        title: "К выполнению"
                        color: warningColor
                        model: pendingJobsModel
                    }
                    KanbanColumn {
                        title: "В работе"
                        color: primaryColor
                        model: runningJobsModel
                    }
                    KanbanColumn {
                        title: "Выполнено"
                        color: successColor
                        model: completedJobsModel
                    }
                    KanbanColumn {
                        title: "Проблемы"
                        color: errorColor
                        model: failedJobsModel
                    }
                }
            }
        }
    }
    
    // ========================================
    // REPORTS PAGE
    // ========================================
    Component {
        id: reportsPage
        Page {
            title: "Отчёты"
            background: Rectangle { color: backgroundColor }
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 24
                
                // Report templates
                GridView {
                    Layout.fillWidth: true
                    height: 200
                    model: reportTemplatesModel
                    cellWidth: 250
                    cellHeight: 100
                    
                    delegate: ReportTemplateCard {}
                }
                
                // Generated reports
                Card {
                    title: "Сформированные отчёты"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    
                    TableView {
                        anchors.fill: parent
                        model: generatedReportsModel
                        
                        TableViewColumn { title: "Наименование"; width: 200 }
                        TableViewColumn { title: "Тип"; width: 100 }
                        TableViewColumn { title: "Период"; width: 100 }
                        TableViewColumn { title: "Дата"; width: 90 }
                        TableViewColumn { title: "Статус"; width: 80 }
                        TableViewColumn { title: "Файл"; width: 80 }
                    }
                }
            }
        }
    }
    
    // ========================================
    // DIALOGS
    // ========================================
    
    // Person dialog
    Dialog {
        id: personDialog
        title: "Контрагент"
        width: 600
        height: 700
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 16
            
            TextField { id: personCodeF; label: "Код *" }
            TextField { id: personNameF; label: "Наименование *" }
            TextField { id: personFullNameF; label: "Полное наименование" }
            TextField { id: personInnF; label: "ИНН" }
            TextField { id: personKppF; label: "КПП" }
            TextField { id: personOgrnF; label: "ОГРН" }
            
            ComboBox {
                label: "Тип"
                model: ["Юр. лицо", "Физ. лицо", "ИП"]
            }
            
            TextField { id: personPhoneF; label: "Телефон" }
            TextField { id: personEmailF; label: "Email" }
            TextField { id: personAddressF; label: "Адрес" }
            TextField { id: personContactF; label: "Контактное лицо" }
            
            TextArea {
                label: "Примечание"
                height: 80
            }
            
            RowLayout {
                Item { Layout.fillWidth: true }
                Button {
                    text: "Отмена"
                    onClicked: personDialog.close()
                }
                Button {
                    text: "Сохранить"
                    onClicked: savePerson()
                }
            }
        }
    }
    
    // Goods dialog
    Dialog {
        id: goodsDialog
        title: "Товар"
        width: 500
        height: 600
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            
            TextField { label: "Код *" }
            TextField { label: "Наименование *" }
            TextField { label: "Полное наименование" }
            TextField { label: "Штрихкод" }
            ComboBox { label: "Тип"; model: ["Товар", "Услуга", "Продукция"] }
            ComboBox { label: "Ед. измерения"; model: ["шт", "кг", "л", "м", "упак"] }
            TextField { label: "Цена" }
            TextField { label: "Себестоимость" }
            TextField { label: "НДС %" }
            
            RowLayout {
                Item { Layout.fillWidth: true }
                Button { text: "Отмена"; onClicked: goodsDialog.close() }
                Button { text: "Сохранить" }
            }
        }
    }
    
    // Bill dialog
    Dialog {
        id: billDialog
        title: "Документ"
        width: 900
        height: 700
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            
            RowLayout {
                ComboBox { label: "Тип документа"; model: ["Счёт", "Счёт-фактура", "Накладная", "Акт"] }
                TextField { label: "Номер" }
                DateField { label: "Дата" }
                DateField { label: "Срок оплаты" }
            }
            
            ComboBox { label: "Контрагент"; model: personsModel }
            ComboBox { label: "Склад"; model: locationsModel }
            
            // Bill items table
            TableView {
                height: 250
                model: billItemsModel
                
                TableViewColumn { title: "Товар"; width: 200 }
                TableViewColumn { title: "Кол-во"; width: 80 }
                TableViewColumn { title: "Ед."; width: 50 }
                TableViewColumn { title: "Цена"; width: 80 }
                TableViewColumn { title: "Сумма"; width: 100 }
            }
            
            RowLayout {
                Button { text: "➕ Добавить строку" }
                Button { text: "🗑 Удалить" }
                Item { Layout.fillWidth: true }
                Label { text: "Итого: 0.00" }
            }
            
            TextArea { label: "Примечание"; height: 60 }
            
            RowLayout {
                Item { Layout.fillWidth: true }
                Button { text: "Отмена"; onClicked: billDialog.close() }
                Button { text: "Черновик"; onClicked: saveBillDraft() }
                Button { text: "Провести"; onClicked: approveBill() }
            }
        }
    }
    
    // ========================================
    // NOTIFICATIONS POPUP
    // ========================================
    Popup {
        id: notificationsPopup
        width: 350
        height: 400
        
        ColumnLayout {
            Label { text: "Уведомления"; font.bold: true; font.pixelSize: 16 }
            
            ListView {
                model: notificationsModel
                delegate: NotificationItem {}
            }
        }
    }
    
    // ========================================
    // FOOTER STATUS BAR
    // ========================================
    footer: StatusBar {
        height: 28
        background: Rectangle { color: "#EEEEEE" }
        
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            
            Label { text: "Пользователь: " + userName }
            Label { text: " | " }
            Label { text: "Организация: " + companyName }
            Item { Layout.fillWidth: true }
            Label { text: "База данных: Подключена ✓" }
            Label { text: " | " }
            Label { text: "Версия: 0.1.0" }
        }
    }
    
    // ========================================
    // FUNCTIONS
    // ========================================
    function navigateTo(page) {
        contentStack.push(page)
    }
    
    function executeSearch() {
        console.log("Searching: " + globalSearch.text)
    }
    
    function logout() {
        console.log("Logout")
    }
    
    // Data properties
    property string userName: "Администратор"
    property string userEmail: "admin@surypus.local"
    property string userStatus: "online"
    property string companyName: "ООО ТехноСтрой"
    
    property int personPage: 1
    property int personTotalPages: 10
    
    property string billTotalSum: "0.00"
    property string billTotalVat: "0.00"
    
    // Stats
    property var stats: ({persons: "125", goods: "1,234", bills: "89", jobs: "12", locations: "5"})
    
    // Models (placeholder)
    property var recentDocsModel: ListModel {}
    property var pendingTasksModel: ListModel {}
    property var personsModel: ListModel {}
    property var goodsModel: ListModel {}
    property var billsModel: ListModel {}
    property var locationsModel: ListModel {}
    property var accountsModel: ListModel {}
    property var entriesModel: ListModel {}
    property var employeesModel: ListModel {}
    property var payrollModel: ListModel {}
    property var pendingJobsModel: ListModel {}
    property var runningJobsModel: ListModel {}
    property var completedJobsModel: ListModel {}
    property var failedJobsModel: ListModel {}
    property var reportTemplatesModel: ListModel {}
    property var generatedReportsModel: ListModel {}
    property var billItemsModel: ListModel {}
    property var notificationsModel: ListModel {}
    
    // Dialogs
    property alias personDialog: personDialog
    property alias goodsDialog: goodsDialog
    property alias billDialog: billDialog
    property alias profileDialog: profileDialog
    property alias settingsDialog: settingsDialog
    property alias helpDialog: helpDialog
    
    Dialog { id: profileDialog; title: "Профиль"; width: 400; height: 300 }
    Dialog { id: settingsDialog; title: "Настройки"; width: 600; height: 500 }
    Dialog { id: helpDialog; title: "Справка"; width: 800; height: 600 }
    
    // ========================================
    // ADDITIONAL DIALOGS
    // ========================================
    
    // Location Dialog
    Dialog {
        id: locationDialog
        title: "Склад / Магазин"
        width: 500
        height: 550
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 16
            
            RowLayout {
                spacing: 8
                Text { text: "Тип:"; width: 100 }
                ComboBox {
                    width: 200
                    model: ["Склад", "Магазин"]
                    onCurrentTextChanged: console.log("Selected:", currentText)
                }
            }
            
            TextField { id: locCodeF; label: "Код *" }
            TextField { id: locNameF; label: "Наименование *" }
            TextField { id: locAddressF; label: "Адрес" }
            TextField { id: locPhoneF; label: "Телефон" }
            TextField { id: locContactF; label: "Контактное лицо" }
            TextField { id: locCapacityF; label: "Площадь (м²)" }
            
            RowLayout {
                CheckBox { id: locActiveF; text: "Активен"; checked: true }
            }
            
            TextArea { id: locMemoF; label: "Примечание"; height: 60 }
            
            RowLayout {
                Item { Layout.fillWidth: true }
                Button { text: "Отмена"; onClicked: locationDialog.close() }
                Button { text: "Сохранить"; onClicked: saveLocation() }
            }
        }
    }
    
    // Payment Dialog
    Dialog {
        id: paymentDialog
        title: "Платёж"
        width: 500
        height: 450
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 16
            
            RowLayout {
                spacing: 8
                Text { text: "Тип:"; width: 80 }
                ComboBox {
                    width: 180
                    model: ["Приход", "Расход"]
                }
            }
            
            DateField { id: payDateF; label: "Дата платежа" }
            ComboBox { id: payBillF; label: "Документ"; width: 200; model: billsModel }
            ComboBox { id: payPersonF; label: "Контрагент"; width: 200; model: personsModel }
            TextField { id: payAmountF; label: "Сумма *" }
            
            RowLayout {
                spacing: 8
                Text { text: "Валюта:"; width: 80 }
                ComboBox {
                    width: 180
                    model: ["RUB", "USD", "EUR"]
                }
            }
            
            TextField { id: payRateF; label: "Курс" }
            TextField { id: payRefF; label: "Номер документа" }
            ComboBox { id: payMethodF; label: "Способ оплаты"; width: 200; model: ["Наличные", "Безналичные", "Карта"] }
            TextArea { id: payMemoF; label: "Примечание"; height: 60 }
            
            RowLayout {
                Item { Layout.fillWidth: true }
                Button { text: "Отмена"; onClicked: paymentDialog.close() }
                Button { text: "Сохранить"; onClicked: savePayment() }
            }
        }
    }
    
    // Job Dialog
    Dialog {
        id: jobDialog
        title: "Задача"
        width: 550
        height: 500
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 16
            
            TextField { id: jobCodeF; label: "Код" }
            TextField { id: jobNameF; label: "Название *" }
            
            RowLayout {
                spacing: 8
                Text { text: "Тип:"; width: 80 }
                ComboBox {
                    width: 180
                    model: ["ETL", "Отчёт", "Синхронизация", "Уведомление"]
                }
            }
            
            ComboBox { id: jobPriorityF; label: "Приоритет"; width: 200; model: ["1-Высокий", "3-Средний", "5-Обычный", "9-Низкий"] }
            DateField { id: jobScheduledF; label: "Запланировано" }
            
            TextArea { id: jobPayloadF; label: "Параметры (JSON)"; height: 100 }
            TextArea { id: jobMemoF; label: "Примечание"; height: 80 }
            
            RowLayout {
                Item { Layout.fillWidth: true }
                Button { text: "Отмена"; onClicked: jobDialog.close() }
                Button { text: "Создать"; onClicked: createJob() }
            }
        }
    }
    
    // Employee Dialog
    Dialog {
        id: employeeDialog
        title: "Сотрудник"
        width: 550
        height: 550
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 16
            
            TextField { id: empCodeF; label: "Табельный № *" }
            ComboBox { id: empPersonF; label: "Физ. лицо"; width: 200; model: personsModel }
            TextField { id: empPositionF; label: "Должность" }
            TextField { id: empDeptF; label: "Подразделение" }
            TextField { id: empSalaryF; label: "Оклад" }
            DateField { id: empHireF; label: "Дата приёма" }
            
            RowLayout {
                spacing: 8
                Text { text: "Статус:"; width: 80 }
                ComboBox {
                    width: 180
                    model: ["Работает", "В отпуске", "Больничный", "Уволен"]
                }
            }
            
            TextField { id: empPhoneF; label: "Телефон" }
            TextField { id: empEmailF; label: "Email" }
            TextArea { id: empMemoF; label: "Примечание"; height: 60 }
            
            RowLayout {
                Item { Layout.fillWidth: true }
                Button { text: "Отмена"; onClicked: employeeDialog.close() }
                Button { text: "Сохранить"; onClicked: saveEmployee() }
            }
        }
    }
    
    // Report Schedule Dialog
    Dialog {
        id: reportScheduleDialog
        title: "Расписание отчёта"
        width: 500
        height: 450
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 16
            
            TextField { id: rsNameF; label: "Название *" }
            ComboBox { id: rsReportF; label: "Отчёт"; width: 200; model: reportTemplatesModel }
            TextField { id: rsCronF; label: "Cron (0 0 * * *)" }
            TextArea { id: rsParamsF; label: "Параметры (JSON)"; height: 100 }
            
            RowLayout {
                CheckBox { id: rsEnabledF; text: "Включено"; checked: true }
            }
            
            RowLayout {
                Item { Layout.fillWidth: true }
                Button { text: "Отмена"; onClicked: reportScheduleDialog.close() }
                Button { text: "Сохранить"; onClicked: saveReportSchedule() }
            }
        }
    }
    
    // Currency Dialog
    Dialog {
        id: currencyDialog
        title: "Валюта"
        width: 450
        height: 400
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 16
            
            TextField { id: currCodeF; label: "Код (ISO 4217) *" }
            TextField { id: currNameF; label: "Наименование *" }
            TextField { id: currSymbolF; label: "Символ" }
            TextField { id: currRateF; label: "Курс к базовой валюте" }
            
            RowLayout {
                CheckBox { id: currBaseF; text: "Базовая валюта" }
                CheckBox { id: currActiveF; text: "Активна"; checked: true }
            }
            
            RowLayout {
                Item { Layout.fillWidth: true }
                Button { text: "Отмена"; onClicked: currencyDialog.close() }
                Button { text: "Сохранить"; onClicked: saveCurrency() }
            }
        }
    }
    
    // Tax Dialog
    Dialog {
        id: taxDialog
        title: "Налог"
        width: 450
        height: 400
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 16
            
            TextField { id: taxNameF; label: "Наименование *" }
            TextField { id: taxRateF; label: "Ставка (%)" }
            
            RowLayout {
                spacing: 8
                Text { text: "Тип:"; width: 80 }
                ComboBox {
                    width: 180
                    model: ["НДС", "Акциз", "Налог на прибыль", "УСН"]
                }
            }
            
            RowLayout {
                CheckBox { id: taxActiveF; text: "Активен"; checked: true }
            }
            
            RowLayout {
                Item { Layout.fillWidth: true }
                Button { text: "Отмена"; onClicked: taxDialog.close() }
                Button { text: "Сохранить"; onClicked: saveTax() }
            }
        }
    }
    
    // Account Dialog (Accounting)
    Dialog {
        id: accountDialog
        title: "Счёт (План счетов)"
        width: 500
        height: 450
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 16
            
            TextField { id: accCodeF; label: "Код счёта *" }
            TextField { id: accNameF; label: "Наименование *" }
            
            RowLayout {
                spacing: 8
                Text { text: "Тип:"; width: 80 }
                ComboBox {
                    width: 180
                    model: ["Активный", "Пассивный", "Активно-Пассивный", "Забалансовый"]
                }
            }
            
            ComboBox { id: accParentF; label: "Родительский счёт"; width: 200; model: accountsModel }
            
            RowLayout {
                CheckBox { id: accActiveF; text: "Активен"; checked: true }
            }
            
            TextArea { id: accMemoF; label: "Описание"; height: 80 }
            
            RowLayout {
                Item { Layout.fillWidth: true }
                Button { text: "Отмена"; onClicked: accountDialog.close() }
                Button { text: "Сохранить"; onClicked: saveAccount() }
            }
        }
    }
}