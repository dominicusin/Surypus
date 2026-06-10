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

    property var editData: null
    signal saved(var data)

    function loadData() {
        if (editData) {
            typeCombo.currentIndex = editData.billType || 0;
            numberField.text = editData.billCode || "";
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24

        RowLayout {
            ComboBox { id: typeCombo; label: "Тип документа"; model: ["Счёт", "Счёт-фактура", "Накладная", "Акт"] }
            TextField { id: numberField; label: "Номер" }
            TextField { id: dateField; label: "Дата"; placeholderText: "ГГГГ-ММ-ДД" }
        }

        TextField { id: personField; label: "Контрагент (ID)"; placeholderText: "ID контрагента" }
        TextField { id: locationField; label: "Склад (ID)"; placeholderText: "ID склада" }

        Item { Layout.fillHeight: true }

        RowLayout {
            Item { Layout.fillWidth: true }
            Button { text: "Отмена"; onClicked: billDialog.close() }
            Button {
                text: editData ? "Сохранить" : "Создать"
                onClicked: {
                    var payload = {
                        billCode: numberField.text,
                        billType: typeCombo.currentIndex,
                        billStatus: 0,
                        billDate: dateField.text,
                        billPersonId: parseInt(personField.text) || null,
                        billLocationId: parseInt(locationField.text) || null,
                        billTotal: 0,
                        billDiscount: 0,
                        billTaxAmount: 0
                    };
                    saved(payload);
                    billDialog.close();
                }
            }
        }
    }
}
