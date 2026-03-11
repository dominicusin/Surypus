import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15

Window {
    width: 1200
    height: 800
    visible: true
    title: "Surypus ERP/CRM"
    color: "#f5f5f5"

    property string apiBase: "http://localhost:8080/api/v1"

    Rectangle {
        id: header
        width: parent.width
        height: 80
        color: "#667eea"

        Column {
            anchors.centerIn: parent
            Text {
                text: "Surypus ERP/CRM"
                color: "white"
                font.pixelSize: 28
                font.bold: true
            }
            Text {
                text: "Version 0.1.0"
                color: "white"
                font.pixelSize: 14
                opacity: 0.8
            }
        }
    }

    Row {
        id: nav
        width: parent.width
        height: 50
        anchors.top: header.bottom
        spacing: 10
        padding: 10

        Button {
            text: "Контрагенты"
            onClicked: loadPersons()
        }
        Button {
            text: "Товары"
            onClicked: loadGoods()
        }
        Button {
            text: "Склады"
            onClicked: loadLocations()
        }
        Button {
            text: "Остатки"
            onClicked: loadStock()
        }
        Button {
            text: "Документы"
            onClicked: loadBills()
        }
    }

    Rectangle {
        id: content
        width: parent.width - 20
        height: parent.height - 150
        anchors.top: nav.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.margins: 10
        color: "white"
        radius: 8

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20

            Text {
                id: titleText
                text: "Контрагенты"
                font.pixelSize: 24
                font.bold: true
                color: "#333"
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "white"

                TableView {
                    id: tableView
                    anchors.fill: parent
                    clip: true

                    TableViewColumn { role: "id"; title: "ID"; width: 50 }
                    TableViewColumn { role: "code"; title: "Код"; width: 80 }
                    TableViewColumn { role: "name"; title: "Наименование"; width: 200 }
                    TableViewColumn { role: "inn"; title: "ИНН"; width: 120 }
                    TableViewColumn { role: "kpp"; title: "КПП"; width: 100 }
                    TableViewColumn { role: "phone"; title: "Телефон"; width: 120 }
                    TableViewColumn { role: "email"; title: "Email"; width: 150 }
                    TableViewColumn { role: "creditLimit"; title: "Кредитный лимит"; width: 120 }
                    TableViewColumn { role: "discount"; title: "Скидка %"; width: 80 }

                    model: ListModel {
                        id: tableModel
                    }
                }
            }

            Row {
                spacing: 10
                Button {
                    text: "Добавить"
                    onClicked: console.log("Add new record")
                }
                Button {
                    text: "Обновить"
                    onClicked: refreshCurrent()
                }
                Text {
                    id: statusText
                    text: "Записей: 0"
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }

    function loadPersons() {
        titleText.text = "Контрагенты"
        tableModel.clear()
        
        var xhr = new XMLHttpRequest()
        xhr.open("GET", apiBase + "/persons")
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                var response = JSON.parse(xhr.responseText)
                if (response.status === "ok") {
                    response.data.forEach(function(item) {
                        tableModel.append({
                            id: item.id,
                            code: item.code,
                            name: item.name,
                            inn: item.inn,
                            kpp: item.kpp,
                            phone: item.phone || "",
                            email: item.email || "",
                            creditLimit: item.creditLimit,
                            discount: item.discount
                        })
                    })
                    statusText.text = "Записей: " + response.data.length
                }
            }
        }
        xhr.send()
    }

    function loadGoods() {
        titleText.text = "Товары"
        tableModel.clear()
        
        var xhr = new XMLHttpRequest()
        xhr.open("GET", apiBase + "/goods")
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                var response = JSON.parse(xhr.responseText)
                if (response.status === "ok") {
                    response.data.forEach(function(item) {
                        tableModel.append({
                            id: item.id,
                            code: item.code,
                            name: item.name,
                            barcode: item.barcode || "",
                            goodsType: item.goodsType,
                            unitId: item.unitId,
                            minStock: item.minStock,
                            maxStock: item.maxStock || "",
                            status: item.status
                        })
                    })
                    statusText.text = "Записей: " + response.data.length
                }
            }
        }
        xhr.send()
    }

    function loadLocations() {
        titleText.text = "Склады"
        tableModel.clear()
        
        var xhr = new XMLHttpRequest()
        xhr.open("GET", apiBase + "/locations")
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                var response = JSON.parse(xhr.responseText)
                if (response.status === "ok") {
                    response.data.forEach(function(item) {
                        tableModel.append({
                            id: item.id,
                            code: item.code,
                            name: item.name,
                            locationType: item.locationType,
                            address: item.address || "",
                            capacity: item.capacity || "",
                            status: item.status
                        })
                    })
                    statusText.text = "Записей: " + response.data.length
                }
            }
        }
        xhr.send()
    }

    function loadStock() {
        titleText.text = "Остатки товаров"
        tableModel.clear()
        
        var xhr = new XMLHttpRequest()
        xhr.open("GET", apiBase + "/stock")
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                var response = JSON.parse(xhr.responseText)
                if (response.status === "ok") {
                    response.data.forEach(function(item) {
                        tableModel.append({
                            id: item.id,
                            goodsId: item.goodsId,
                            locationId: item.locationId,
                            quantity: item.quantity,
                            reserved: item.reserved,
                            cost: item.cost,
                            price: item.price,
                            batch: item.batch || ""
                        })
                    })
                    statusText.text = "Записей: " + response.data.length
                }
            }
        }
        xhr.send()
    }

    function loadBills() {
        titleText.text = "Документы"
        tableModel.clear()
        
        var xhr = new XMLHttpRequest()
        xhr.open("GET", apiBase + "/bills")
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                var response = JSON.parse(xhr.responseText)
                if (response.status === "ok") {
                    response.data.forEach(function(item) {
                        tableModel.append({
                            id: item.id,
                            code: item.code,
                            billType: item.billType,
                            dt: item.dt,
                            personId: item.personId,
                            total: item.total,
                            tax: item.tax,
                            status: item.status
                        })
                    })
                    statusText.text = "Записей: " + response.data.length
                }
            }
        }
        xhr.send()
    }

    function refreshCurrent() {
        if (titleText.text === "Контрагенты") loadPersons()
        else if (titleText.text === "Товары") loadGoods()
        else if (titleText.text === "Склады") loadLocations()
        else if (titleText.text === "Остатки товаров") loadStock()
        else if (titleText.text === "Документы") loadBills()
    }

    Component.onCompleted: {
        loadPersons()
    }
}