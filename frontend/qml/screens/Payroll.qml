import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../components"

Page {
    id: payrollPage
    title: "Зарплата"

    readonly property color primaryColor: "#1976D2"
    readonly property color backgroundColor: "#F5F5F5"

    background: Rectangle { color: backgroundColor }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24

        RowLayout {
            Button { text: "➕ Приём сотрудника"; onClicked: console.log("Hire") }
            Button { text: "📄 Начислить зарплату"; onClicked: console.log("Calculate payroll") }
            Button { text: "💸 Выплатить"; onClicked: console.log("Pay salary") }
        }

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

    ListModel { id: employeesModel
        ListElement { tabNum: "001"; name: "Петров А.С."; position: "Директор"; department: "Администрация"; salary: "80 000"; status: "Работает" }
        ListElement { tabNum: "002"; name: "Сидорова Е.П."; position: "Бухгалтер"; department: "Бухгалтерия"; salary: "55 000"; status: "Работает" }
        ListElement { tabNum: "003"; name: "Козлов М.И."; position: "Менеджер"; department: "Продажи"; salary: "45 000"; status: "В отпуске" }
    }

    ListModel { id: payrollModel }
}
