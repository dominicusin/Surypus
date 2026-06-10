import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../components"

Page {
    id: reportsPage
    title: "Отчёты"

    readonly property color primaryColor: "#1976D2"
    readonly property color backgroundColor: "#F5F5F5"

    background: Rectangle { color: backgroundColor }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24

        GridView {
            Layout.fillWidth: true
            height: 200
            model: reportTemplatesModel
            cellWidth: 250
            cellHeight: 100
            delegate: ReportTemplateCard {}
        }

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

    ListModel { id: reportTemplatesModel
        ListElement { name: "Продажи"; type: "sales"; icon: "chart" }
        ListElement { name: "Прибыльность"; type: "profitability"; icon: "money" }
        ListElement { name: "Остатки"; type: "stock"; icon: "box" }
        ListElement { name: "Дебиторы"; type: "debtors"; icon: "people" }
    }

    ListModel { id: generatedReportsModel }
}
