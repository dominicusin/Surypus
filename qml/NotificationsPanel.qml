import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root
    property bool prefEmail: true
    property bool prefPush: true
    property string prefDigest: "daily"
    property bool loading: true

    signal preferencesChanged()

    function loadFromApi() {
        loading = true
    }

    function setPrefs(email, push, digest) {
        prefEmail = email
        prefPush = push
        prefDigest = digest
        loading = false
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        Text {
            text: "Уведомления"
            font.bold: true
            font.pixelSize: 16
        }

        RowLayout {
            spacing: 8
            Text { text: "Email уведомления:" }
            Switch {
                checked: root.prefEmail
                onCheckedChanged: root.preferencesChanged()
            }
        }

        RowLayout {
            spacing: 8
            Text { text: "Push уведомления:" }
            Switch {
                checked: root.prefPush
                onCheckedChanged: root.preferencesChanged()
            }
        }

        RowLayout {
            spacing: 8
            Text { text: "Digest:" }
            ComboBox {
                model: ["daily", "weekly", "none"]
                currentIndex: {
                    switch (root.prefDigest) {
                        case "daily": return 0
                        case "weekly": return 1
                        default: return 2
                    }
                }
                onCurrentIndexChanged: root.preferencesChanged()
            }
        }
    }
}
