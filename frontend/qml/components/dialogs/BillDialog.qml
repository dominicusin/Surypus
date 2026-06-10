import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Dialog {
    id: billDialog
    title: "Документ"
    width: 900
    height: 700
    modal: true
    standardButtons: Dialog.Close

    signal saved(var data)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24

        RowLayout {
            ComboBox { label: "Тип документа"; model: ["Счёт", "Счёт-фактура", "Накладная", "Акт"] }
            TextField { label: "Номер" }
            DateField { label: "Дата" }
        }

        ComboBox { label: "Контрагент"; model: ["ООО ТехноСтрой", "ИП Иванов"] }
        ComboBox { label: "Склад"; model: ["Основной", "Розничный"] }

        TableView {
            height: 250
            model: billItemsModel
            TableViewColumn { title: "Товар"; width: 200 }
            TableViewColumn { title: "Кол-во"; width: 80 }
            TableViewColumn { title: "Цена"; width: 80 }
            TableViewColumn { title: "Сумма"; width: 100 }
        }

        RowLayout {
            Button { text: "➕ Добавить строку" }
            Item { Layout.fillWidth: true }
            Label { text: "Итого: 0.00" }
        }

        RowLayout {
            Item { Layout.fillWidth: true }
            Button { text: "Отмена"; onClicked: billDialog.close() }
            Button { text: "Провести"; onClicked: { saved({}); billDialog.close() } }
        }
    }

    ListModel { id: billItemsModel }
}
