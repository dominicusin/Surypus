import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Dialog {
    id: goodsDialog
    title: "Товар / Услуга"
    width: 500
    height: 400
    modal: true
    standardButtons: Dialog.Close

    property var editData: null
    signal saved(var data)

    function loadData() {
        if (editData) {
            codeField.text = editData.goodsCode || "";
            nameField.text = editData.goodsName || "";
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24

        TextField { id: codeField; label: "Код"; placeholderText: "Артикул" }
        TextField { id: nameField; label: "Наименование *"; placeholderText: "Название товара" }
        TextField { id: barcodeField; label: "Штрихкод"; placeholderText: "EAN-13" }
        TextField { id: unitField; label: "Ед. изм. (ID)"; placeholderText: "ID единицы измерения" }

        Item { Layout.fillHeight: true }

        RowLayout {
            Item { Layout.fillWidth: true }
            Button { text: "Отмена"; onClicked: goodsDialog.close() }
            Button {
                text: editData ? "Сохранить" : "Создать"
                onClicked: {
                    saved({
                        goodsCode: codeField.text,
                        goodsName: nameField.text,
                        goodsBarcode: barcodeField.text || null,
                        goodsUnitId: parseInt(unitField.text) || null
                    });
                    goodsDialog.close();
                }
            }
        }
    }
}
