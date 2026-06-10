import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../components"

Page {
    id: personsPage
    title: "Контрагенты"

    readonly property color primaryColor: "#1976D2"
    readonly property color backgroundColor: "#F5F5F5"

    property int personPage: 1
    property int personTotalPages: 5

    background: Rectangle { color: backgroundColor }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 16

        RowLayout {
            Button { text: "➕ Добавить"; icon.source: "qrc:/icons/add.png"; onClicked: console.log("Add person") }
            Button { text: "📥 Импорт"; onClicked: console.log("Import") }
            Button { text: "📤 Экспорт"; onClicked: console.log("Export") }
            Item { Layout.fillWidth: true }
            ComboBox { id: personTypeFilter; width: 150; model: ["Все типы", "Юр. лицо", "Физ. лицо", "ИП"] }
            ComboBox { id: personStatusFilter; width: 150; model: ["Все статусы", "Активные", "Неактивные"] }
            TextField { id: personSearch; width: 250; placeholderText: "Поиск по наименованию, ИНН..." }
        }

        Card {
            Layout.fillWidth: true
            Layout.fillHeight: true

            TableView {
                id: personsTable
                anchors.fill: parent
                model: personsModel
                headerVisible: true
                rowHeight: 48
                TableViewColumn { title: "Код"; width: 80; role: "code" }
                TableViewColumn { title: "Наименование"; width: 200; role: "name" }
                TableViewColumn { title: "ИНН"; width: 110; role: "inn" }
                TableViewColumn { title: "КПП"; width: 90; role: "kpp" }
                TableViewColumn { title: "Тип"; width: 80; role: "type" }
                TableViewColumn { title: "Телефон"; width: 120; role: "phone" }
                TableViewColumn { title: "Email"; width: 160; role: "email" }
                TableViewColumn { title: "Статус"; width: 80; role: "status" }
            }
        }

        Paginator { currentPage: personPage; totalPages: personTotalPages }
    }

    ListModel { id: personsModel
        ListElement { code: "P001"; name: "ООО ТехноСтрой"; inn: "7701234567890"; kpp: "770101001"; type: "Юр. лицо"; phone: "+7 495 123-4567"; email: "info@tehnostroy.ru"; status: "Активен" }
        ListElement { code: "P002"; name: "ИП Иванов И.И."; inn: "7709876543210"; kpp: ""; type: "ИП"; phone: "+7 916 123-4567"; email: "ivanov@mail.ru"; status: "Активен" }
        ListElement { code: "P003"; name: "ООО МегаТрейд"; inn: "7705555555555"; kpp: "770201001"; type: "Юр. лицо"; phone: "+7 495 987-6543"; email: "info@megatrade.ru"; status: "Активен" }
    }
}
