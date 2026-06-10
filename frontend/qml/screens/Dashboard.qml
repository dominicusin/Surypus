import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../components"

Page {
    id: dashboardPage

    readonly property color primaryColor: "#1976D2"
    readonly property color primaryDark: "#1565C0"
    readonly property color primaryLight: "#42A5F5"
    readonly property color secondaryColor: "#FF5722"
    readonly property color backgroundColor: "#F5F5F5"
    readonly property color successColor: "#4CAF50"
    readonly property color warningColor: "#FFC107"
    readonly property color errorColor: "#F44336"

    property var stats: ({
        persons: "125", goods: "1 234", bills: "89",
        jobs: "12", locations: "5", revenue: "2.4M",
        expenses: "1.8M", profit: "600K"
    })

    signal navigateToPage(string page)

    background: Rectangle { color: backgroundColor }

    ScrollView {
        anchors.fill: parent
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 20

            RowLayout {
                spacing: 16
                StatCard { title: "Контрагенты"; value: stats.persons; icon: "qrc:/icons/people.png"; color: primaryColor; onClicked: navigateToPage("PersonsPage.qml") }
                StatCard { title: "Товары"; value: stats.goods; icon: "qrc:/icons/goods.png"; color: successColor; onClicked: navigateToPage("GoodsPage.qml") }
                StatCard { title: "Документы"; value: stats.bills; icon: "qrc:/icons/document.png"; color: secondaryColor; onClicked: navigateToPage("BillsPage.qml") }
                StatCard { title: "Задачи"; value: stats.jobs; icon: "qrc:/icons/tasks.png"; color: "#9C27B0"; onClicked: navigateToPage("JobsPage.qml") }
                StatCard { title: "Склады"; value: stats.locations; icon: "qrc:/icons/warehouse.png"; color: "#FF9800"; onClicked: navigateToPage("LocationsPage.qml") }
            }

            RowLayout {
                spacing: 16
                Layout.fillWidth: true

                Card {
                    title: "Последние документы"
                    Layout.preferredWidth: 500
                    Layout.fillHeight: true

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

                Card {
                    title: "Ожидающие задачи"
                    Layout.preferredWidth: 400
                    Layout.fillHeight: true

                    ListView {
                        anchors.fill: parent
                        model: pendingTasksModel
                        delegate: TaskDelegate {}
                    }
                }
            }

            Card {
                title: "Быстрые действия"
                height: 100
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12
                    QuickActionButton { icon: "qrc:/icons/add_person.png"; label: "Новый контрагент"; onClicked: console.log("Create person") }
                    QuickActionButton { icon: "qrc:/icons/add_goods.png"; label: "Новый товар"; onClicked: console.log("Create goods") }
                    QuickActionButton { icon: "qrc:/icons/add_bill.png"; label: "Новый счёт"; onClicked: console.log("Create bill") }
                    QuickActionButton { icon: "qrc:/icons/add_job.png"; label: "Новая задача"; onClicked: console.log("Create job") }
                }
            }
        }
    }

    ListModel { id: recentDocsModel
        ListElement { number: "INV-2026-089"; date: "27.03.2026"; customer: "ООО ТехноСтрой"; total: "50 000 ₽"; status: "Проведён" }
        ListElement { number: "INV-2026-088"; date: "26.03.2026"; customer: "ИП Иванов"; total: "25 000 ₽"; status: "На утверждении" }
        ListElement { number: "INV-2026-087"; date: "25.03.2026"; customer: "ООО МегаТрейд"; total: "75 000 ₽"; status: "Черновик" }
    }

    ListModel { id: pendingTasksModel
        ListElement { taskTitle: "Отправить отчёт"; taskPriority: "Высокий"; taskDueDate: "28.03.2026"; taskStatus: "Ожидает" }
        ListElement { taskTitle: "Обработать платежи"; taskPriority: "Высокий"; taskDueDate: "27.03.2026"; taskStatus: "В работе" }
        ListElement { taskTitle: "Сформировать накладную"; taskPriority: "Средний"; taskDueDate: "27.03.2026"; taskStatus: "Ожидает" }
    }
}
