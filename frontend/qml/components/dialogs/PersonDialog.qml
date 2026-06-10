import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Dialog {
    id: personDialog
    title: "Контрагент"
    width: 500
    height: 450
    modal: true
    standardButtons: Dialog.Close

    property var editData: null
    signal saved(var data)

    function loadData() {
        if (editData) {
            nameField.text = editData.personName || "";
            codeField.text = editData.personCode || "";
            innField.text = editData.personINN || "";
            kppField.text = editData.personKPP || "";
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24

        TextField { id: codeField; label: "Код"; placeholderText: "Код контрагента" }
        TextField { id: nameField; label: "Наименование *"; placeholderText: "Полное наименование" }
        TextField { id: innField; label: "ИНН"; placeholderText: "10 или 12 цифр" }
        TextField { id: kppField; label: "КПП"; placeholderText: "9 цифр" }
        ComboBox { id: typeCombo; label: "Тип"; model: ["Юр. лицо", "ИП", "Физ. лицо"] }

        Item { Layout.fillHeight: true }

        RowLayout {
            Item { Layout.fillWidth: true }
            Button { text: "Отмена"; onClicked: personDialog.close() }
            Button {
                text: editData ? "Сохранить" : "Создать"
                onClicked: {
                    saved({
                        personCode: codeField.text || null,
                        personName: nameField.text,
                        personINN: innField.text || null,
                        personKPP: kppField.text || null,
                        personType: typeCombo.currentIndex + 1,
                        personStatus: 1
                    });
                    personDialog.close();
                }
            }
        }
    }
}
