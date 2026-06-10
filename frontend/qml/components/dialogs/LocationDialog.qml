import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Dialog {
    id: locationDialog
    title: "Склад / Локация"
    width: 400
    height: 300
    modal: true
    standardButtons: Dialog.Close

    property var editData: null
    signal saved(var data)

    function loadData() {
        if (editData) {
            codeField.text = editData.locationCode || "";
            nameField.text = editData.locationName || "";
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24

        TextField { id: codeField; label: "Код"; placeholderText: "Код склада" }
        TextField { id: nameField; label: "Наименование *"; placeholderText: "Название склада" }
        ComboBox { id: typeCombo; label: "Тип"; model: ["Склад", "Магазин", "Офис"] }

        Item { Layout.fillHeight: true }

        RowLayout {
            Item { Layout.fillWidth: true }
            Button { text: "Отмена"; onClicked: locationDialog.close() }
            Button {
                text: editData ? "Сохранить" : "Создать"
                onClicked: {
                    saved({
                        locationCode: codeField.text || null,
                        locationName: nameField.text,
                        locationType: typeCombo.currentIndex
                    });
                    locationDialog.close();
                }
            }
        }
    }
}
