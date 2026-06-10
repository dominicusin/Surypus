import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Dialog {
    id: goodsDialog
    title: "Товар"
    width: 500
    height: 600
    modal: true
    standardButtons: Dialog.Close

    signal saved(var data)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24

        TextField { label: "Код *" }
        TextField { label: "Наименование *" }
        TextField { label: "Штрихкод" }
        ComboBox { label: "Тип"; model: ["Товар", "Услуга", "Продукция"] }
        ComboBox { label: "Ед. измерения"; model: ["шт", "кг", "л", "м", "упак"] }
        TextField { label: "Цена" }
        TextField { label: "НДС %" }

        RowLayout {
            Item { Layout.fillWidth: true }
            Button { text: "Отмена"; onClicked: goodsDialog.close() }
            Button { text: "Сохранить"; onClicked: { saved({}); goodsDialog.close() } }
        }
    }
}
