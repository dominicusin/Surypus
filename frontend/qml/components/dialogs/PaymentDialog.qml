import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Dialog {
    id: paymentDialog
    title: "Платёж"
    width: 450
    height: 350
    modal: true
    standardButtons: Dialog.Close

    signal saved(var data)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24

        TextField { id: amountField; label: "Сумма *"; placeholderText: "0.00" }
        TextField { id: dateField; label: "Дата *"; placeholderText: "ГГГГ-ММ-ДД" }
        TextField { id: billField; label: "Документ (ID)"; placeholderText: "ID счёта" }
        ComboBox { id: methodCombo; label: "Способ"; model: ["Наличные", "Безнал", "Карта", "Электронно"] }

        Item { Layout.fillHeight: true }

        RowLayout {
            Item { Layout.fillWidth: true }
            Button { text: "Отмена"; onClicked: paymentDialog.close() }
            Button {
                text: "Создать"
                onClicked: {
                    saved({
                        paymentAmount: parseFloat(amountField.text) || 0,
                        paymentDate: dateField.text,
                        paymentPersonId: parseInt(billField.text) || 0,
                        paymentMethod: methodCombo.currentIndex
                    });
                    paymentDialog.close();
                }
            }
        }
    }
}
