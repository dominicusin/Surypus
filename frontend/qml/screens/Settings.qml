import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../components"

Page {
    id: settingsPage
    title: "Настройки"

    readonly property color primaryColor: "#1976D2"
    readonly property color backgroundColor: "#F5F5F5"

    background: Rectangle { color: backgroundColor }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 16

        GroupBox {
            title: "Организация"
            Layout.fillWidth: true
            ColumnLayout {
                TextField { label: "Наименование"; text: "ООО ТехноСтрой" }
                TextField { label: "ИНН"; text: "7701234567890" }
                TextField { label: "КПП"; text: "770101001" }
                TextField { label: "ОГРН"; text: "1027700007654" }
            }
        }

        GroupBox {
            title: "Бухгалтерия"
            Layout.fillWidth: true
            ColumnLayout {
                ComboBox { label: "Система налогообложения"; model: ["ОСН", "УСН 6%", "УСН 15%", "ЕНВД"] }
                ComboBox { label: "Валюта учёта"; model: ["RUB", "USD", "EUR"] }
            }
        }

        GroupBox {
            title: "Пользователи"
            Layout.fillWidth: true
            ColumnLayout {
                Label { 
                    text: "Загрузка пользователей..."; 
                    color: "#757575"
                }
            }
        }

        GroupBox {
            title: "Подключения"
            Layout.fillWidth: true
            ColumnLayout {
                Label { 
                    text: "PostgreSQL: Проверка...";
                    color: "#757575"
                }
                Label { 
                    text: "API сервер: Проверка...";
                    color: "#757575"
                }
                Label { 
                    text: "Версия: Загрузка...";
                    color: "#757575"
                }
            }
        }

        Item { Layout.fillHeight: true }

        RowLayout {
            Item { Layout.fillWidth: true }
            Button { text: "Сохранить"; onClicked: console.log("Save settings") }
        }
    }
}
