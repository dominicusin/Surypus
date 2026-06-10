import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../components"

Page {
    id: accountingPage
    title: "Бухгалтерия"

    readonly property color primaryColor: "#1976D2"
    readonly property color backgroundColor: "#F5F5F5"

    background: Rectangle { color: backgroundColor }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24

        Card {
            title: "План счетов"
            Layout.fillWidth: true
            height: 300

            ListView {
                anchors.fill: parent
                model: accountsModel
                delegate: ItemDelegate { text: modelData.code + " — " + modelData.name }
            }
        }

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

    ListModel { id: accountsModel
        ListElement { code: "50"; name: "Касса" }
        ListElement { code: "51"; name: "Расчётный счёт" }
        ListElement { code: "60"; name: "Расчёты с поставщиками" }
        ListElement { code: "62"; name: "Расчёты с покупателями" }
        ListElement { code: "41"; name: "Товары" }
    }

    ListModel { id: entriesModel }
}
