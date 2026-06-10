import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../components"

Page {
    id: locationsPage
    title: "Склады и магазины"

    readonly property color primaryColor: "#1976D2"
    readonly property color backgroundColor: "#F5F5F5"

    background: Rectangle { color: backgroundColor }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24

        RowLayout {
            Button { text: "➕ Добавить склад"; onClicked: console.log("Add warehouse") }
            Button { text: "➕ Добавить магазин"; onClicked: console.log("Add shop") }
        }

        GridView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: locationsModel
            cellWidth: 300
            cellHeight: 200
            delegate: LocationCard {}
        }
    }

    ListModel { id: locationsModel
        ListElement { name: "Основной склад"; type: "warehouse"; address: "г. Москва, ул. Промышленная, д. 10"; stockCount: "850" }
        ListElement { name: "Розничный магазин №1"; type: "shop"; address: "г. Москва, ул. Центральная, д. 25"; stockCount: "320" }
        ListElement { name: "Склад запчастей"; type: "warehouse"; address: "г. Москва, ул. Заводская, д. 5"; stockCount: "64" }
    }
}
