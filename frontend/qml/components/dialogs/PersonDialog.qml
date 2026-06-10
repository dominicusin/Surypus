import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Dialog {
    id: personDialog
    title: "Контрагент"
    width: 600
    height: 700
    modal: true
    standardButtons: Dialog.Close

    property var person: null

    signal saved(var data)

    function setPerson(p) {
        person = p
        if (p) {
            personCodeF.text = p.code || ""
            personNameF.text = p.name || ""
            personFullNameF.text = p.fullName || ""
            personInnF.text = p.inn || ""
            personKppF.text = p.kpp || ""
        }
    }

    function clear() {
        person = null
        personCodeF.text = ""
        personNameF.text = ""
        personFullNameF.text = ""
        personInnF.text = ""
        personKppF.text = ""
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 16

        TextField { id: personCodeF; label: "Код *" }
        TextField { id: personNameF; label: "Наименование *" }
        TextField { id: personFullNameF; label: "Полное наименование" }
        TextField { id: personInnF; label: "ИНН" }
        TextField { id: personKppF; label: "КПП" }
        TextField { id: personPhoneF; label: "Телефон" }
        TextField { id: personEmailF; label: "Email" }

        RowLayout {
            Item { Layout.fillWidth: true }
            Button { text: "Отмена"; onClicked: personDialog.close() }
            Button { text: "Сохранить"; onClicked: {
                saved({code: personCodeF.text, name: personNameF.text, inn: personInnF.text})
                personDialog.close()
            }}
        }
    }
}
