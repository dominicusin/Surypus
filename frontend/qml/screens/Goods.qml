import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../components"

Page {
    id: goodsPage
    title: "Товары и услуги"

    readonly property color primaryColor: "#1976D2"
    readonly property color backgroundColor: "#F5F5F5"

    background: Rectangle { color: backgroundColor }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 16

        RowLayout {
            Button { text: "➕ Добавить"; onClicked: console.log("Add goods") }
            Button { text: "📁 Группы"; onClicked: console.log("Groups") }
            Button { text: "📊 Остатки"; onClicked: console.log("Stock") }
            Item { Layout.fillWidth: true }
            ComboBox { model: ["Все", "Товары", "Услуги", "Продукция"] }
            ComboBox { model: ["Все группы", "Стройматериалы", "Инструменты"] }
            TextField { width: 250; placeholderText: "Поиск..." }
        }

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

    ListModel { id: goodsModel
        ListElement { code: "G001"; name: "Стройматериалы"; unit: "кг"; price: "100"; quantity: "500"; group: "Стройматериалы"; vatRate: "20"; status: "Активен" }
        ListElement { code: "G002"; name: "Инструменты"; unit: "шт"; price: "250"; quantity: "100"; group: "Инструменты"; vatRate: "20"; status: "Активен" }
        ListElement { code: "G003"; name: "Крепёж"; unit: "кг"; price: "50"; quantity: "1000"; group: "Крепёж"; vatRate: "20"; status: "Активен" }
    }
}
