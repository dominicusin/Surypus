import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15
import "components"
import "screens"

ApplicationWindow {
    id: appWindow
    width: 1400
    height: 900
    minimumWidth: 1200
    minimumHeight: 700
    visible: true
    title: "Surypus ERP — Управление предприятием"

    readonly property color primaryColor: "#1976D2"
    readonly property color primaryDark: "#1565C0"
    readonly property color backgroundColor: "#F5F5F5"
    readonly property color surfaceColor: "#FFFFFF"
    readonly property color textPrimary: "#212121"
    readonly property color textSecondary: "#757575"
    readonly property color successColor: "#4CAF50"
    readonly property color warningColor: "#FFC107"
    readonly property color errorColor: "#F44336"

    property string userName: "Администратор"
    property string userEmail: "admin@surypus.local"
    property string companyName: "ООО ТехноСтрой"
    property string currentPage: "dashboard"

    AppState { id: appState }
    RestClient { id: restClient }
    WsClient { id: wsClient; authToken: restClient.jwtToken }

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

            ToolButton {
                icon.source: "qrc:/icons/menu.png"
                icon.color: "white"
                onClicked: drawer.visible = !drawer.visible
            }

            Label {
                text: "🏢 Surypus ERP"
                font.pixelSize: 22
                font.bold: true
                color: "white"
                leftPadding: 8
            }

            Item { Layout.fillWidth: true }

            TextField {
                id: globalSearch
                width: 300
                placeholderText: "Быстрый поиск (Ctrl+F)..."
                background: Rectangle { radius: 4; color: "white"; opacity: 0.95 }
            }

            ToolButton {
                icon.source: "qrc:/icons/bell.png"
                icon.color: "white"
                onClicked: notificationsPopup.open()
            }

            Button {
                text: "👤 " + userName + " ▾"
                flat: true
                textColor: "white"
                onClicked: userMenu.open()
            }
        }
    }

    Drawer {
        id: drawer
        width: 280
        height: parent.height
        background: surfaceColor

        ColumnLayout {
            anchors.fill: parent

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
                    Label { text: userName; font.pixelSize: 16; font.bold: true; color: "white" }
                    Label { text: userEmail; font.pixelSize: 12; color: "white"; opacity: 0.8 }
                    Label { text: "Статус: Онлайн"; font.pixelSize: 10; color: successColor }
                }
            }

            ListView {
                id: navigationView
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: navigationModel
                delegate: NavItem {
                    title: model.title
                    badge: model.badge
                    onClicked: { navigateTo(model.page); drawer.visible = false }
                }
            }
        }
    }

    ListModel {
        id: navigationModel
        ListElement { title: "📊 Главная"; page: "Dashboard"; badge: 0 }
        ListElement { title: "👥 Контрагенты"; page: "Persons"; badge: 5 }
        ListElement { title: "📦 Товары и услуги"; page: "Goods"; badge: 0 }
        ListElement { title: "🏭 Склады"; page: "Locations"; badge: 0 }
        ListElement { title: "📋 Документы"; page: "Bills"; badge: 12 }
        ListElement { title: "💰 Бухгалтерия"; page: "Accounting"; badge: 0 }
        ListElement { title: "👨‍💼 Зарплата"; page: "Payroll"; badge: 0 }
        ListElement { title: "📊 Отчёты"; page: "Reports"; badge: 0 }
        ListElement { title: "✅ Задачи"; page: "Jobs"; badge: 3 }
        ListElement { title: "⚙️ Настройки"; page: "Settings"; badge: 0 }
    }

    StackView {
        id: contentStack
        anchors.fill: parent
        initialItem: dashboardComponent
    }

    Component { id: dashboardComponent; Dashboard { onNavigateToPage: navigateTo(page) } }
    Component { id: personsComponent; Persons {} }
    Component { id: goodsComponent; Goods {} }
    Component { id: billsComponent; Bills {} }
    Component { id: locationsComponent; Locations {} }
    Component { id: accountingComponent; Accounting {} }
    Component { id: payrollComponent; Payroll {} }
    Component { id: reportsComponent; Reports {} }
    Component { id: jobsComponent; Jobs {} }
    Component { id: settingsComponent; Settings {} }

    Popup {
        id: notificationsPopup
        width: 350
        height: 400
        x: parent.width - width - 16
        y: 64

        ColumnLayout {
            Label { text: "Уведомления"; font.bold: true; font.pixelSize: 16 }
            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                model: notificationsModel
                delegate: NotificationItem {}
            }
        }
    }

    ListModel { id: notificationsModel
        ListElement { title: "Новый счёт"; text: "Создан счёт INV-2026-090"; time: "10:30" }
        ListElement { title: "Задача выполнена"; text: "Обработаны платежи"; time: "09:15" }
        ListElement { title: "Низкий остаток"; text: "Крепёж: 50 кг"; time: "Вчера" }
    }

    Menu {
        id: userMenu
        MenuItem { text: "👤 Профиль" }
        MenuItem { text: "⚙️ Настройки" }
        MenuSeparator {}
        MenuItem { text: "❓ Справка" }
        MenuSeparator {}
        MenuItem { text: "🚪 Выход"; onTriggered: Qt.quit() }
    }

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

    function navigateTo(page) {
        contentStack.pop(null)
        switch (page) {
            case "Dashboard": contentStack.push(dashboardComponent); break
            case "Persons": contentStack.push(personsComponent); break
            case "Goods": contentStack.push(goodsComponent); break
            case "Bills": contentStack.push(billsComponent); break
            case "Locations": contentStack.push(locationsComponent); break
            case "Accounting": contentStack.push(accountingComponent); break
            case "Payroll": contentStack.push(payrollComponent); break
            case "Reports": contentStack.push(reportsComponent); break
            case "Jobs": contentStack.push(jobsComponent); break
            case "Settings": contentStack.push(settingsComponent); break
        }
        currentPage = page
    }
}
