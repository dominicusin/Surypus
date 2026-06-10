import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Dialogs 1.3
import "../components"

Page {
    id: billsPage
    title: "Документы"

    readonly property color primaryColor: "#1976D2"
    readonly property color backgroundColor: "#F5F5F5"

    property string billTotalSum: "150 000"
    property string billTotalVat: "25 000"

    background: Rectangle { color: backgroundColor }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 16

        RowLayout {
            MenuButton {
                text: "➕ Создать"
                menu: ContextMenu {
                    MenuItem { text: "Счёт на оплату"; onTriggered: console.log("Create bill") }
                    MenuItem { text: "Счёт-фактура"; onTriggered: console.log("Create invoice") }
                    MenuItem { text: "Товарная накладная"; onTriggered: console.log("Create waybill") }
                    MenuItem { text: "Акт выполненных работ"; onTriggered: console.log("Create act") }
                }
            }
            Button { text: "📋 Шаблоны"; onClicked: console.log("Templates") }
            Item { Layout.fillWidth: true }
            Label { text: "Период:" }
            DateField { id: dateFrom }
            Label { text: " - " }
            DateField { id: dateTo }
            ComboBox { model: ["Все типы", "Счета", "Накладные", "Акты"] }
            ComboBox { model: ["Все статусы", "Черновик", "На утверждении", "Проведён", "Отменён"] }
        }

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

        RowLayout {
            Label { text: "Итого: " + billTotalSum + " руб." }
            Label { text: "НДС: " + billTotalVat + " руб." }
        }
    }

    ListModel { id: billsModel
        ListElement { number: "INV-2026-089"; date: "27.03.2026"; type: "Счёт"; customer: "ООО ТехноСтрой"; total: "50 000"; vat: "8 333"; location: "Основной"; status: "Проведён"; author: "admin" }
        ListElement { number: "INV-2026-088"; date: "26.03.2026"; type: "Счёт"; customer: "ИП Иванов"; total: "25 000"; vat: "4 167"; location: "Основной"; status: "На утвержд."; author: "admin" }
        ListElement { number: "INV-2026-087"; date: "25.03.2026"; type: "Счёт"; customer: "ООО МегаТрейд"; total: "75 000"; vat: "12 500"; location: "Розничный"; status: "Черновик"; author: "buh" }
    }
}
