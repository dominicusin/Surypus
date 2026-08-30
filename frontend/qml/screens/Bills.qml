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
            Button {
                text: "➕ Создать"
                onClicked: billDialog.open()
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

    ListModel { id: billsModel }

    function refreshBills() {
        restClient.loadBills(1, 50)
    }

    function populateBills(items) {
        billsModel.clear()
        if (!items) return
        for (var i = 0; i < items.length; i++) {
            var b = items[i]
            billsModel.append({
                number:   b.number   || b.billCode || ("#" + b.id),
                date:     b.date     || b.billDate || "",
                type:     b.type     || b.billType || "",
                customer: b.customer || b.personName || b.personId || "",
                total:    b.total    || b.amount || "0",
                vat:      b.vat      || b.taxAmount || "0",
                location: b.location || b.locationId || "",
                status:   b.status   || (b.billStatus !== undefined ? b.billStatus : ""),
                author:   b.author   || b.userName || ""
            })
        }
    }

    Component.onCompleted: {
        refreshBills()
        restClient.billsLoaded.connect(populateBills)
    }

    BillDialog {
        id: billDialog
        onSaved: function(data) {
            console.log("Bill saved:", JSON.stringify(data))
            if (restClient) {
                restClient.createBill(data, function() {
                    console.log("Bill created — reloading list")
                    refreshBills()
                })
            }
        }
    }
}
