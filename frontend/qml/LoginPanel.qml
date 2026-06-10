import QtQuick 2.15
import QtQuick.Controls 2.15

Page {
    id: loginPage
    width: 360
    height: 280

    signal loginSucceeded(string token)

    property var restClient: null

    Column {
        anchors.centerIn: parent
        spacing: 12

        Text {
            text: "Surypus ERP"
            font.pixelSize: 24
            font.bold: true
            color: "#1976D2"
            horizontalAlignment: Text.AlignHCenter
            width: parent.width
        }

        Text {
            text: "Вход в систему"
            font.pixelSize: 14
            color: "#757575"
            horizontalAlignment: Text.AlignHCenter
            width: parent.width
            bottomPadding: 8
        }

        TextField {
            id: usernameField
            placeholderText: "Имя пользователя"
            width: 280
            anchors.horizontalCenter: parent.horizontalCenter
        }

        TextField {
            id: passwordField
            placeholderText: "Пароль"
            echoMode: TextInput.Password
            width: 280
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Button {
            text: "Войти"
            width: 280
            anchors.horizontalCenter: parent.horizontalCenter
            onClicked: login(usernameField.text, passwordField.text)
        }

        Text {
            id: loginStatus
            color: "red"
            text: ""
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    function login(user, pass) {
        var xhr = new XMLHttpRequest()
        xhr.open("POST", (restClient ? restClient.apiBaseUrl : "http://localhost:8080/api/v1") + "/auth/login", true)
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4) {
                if (xhr.status === 200) {
                    try {
                        var resp = JSON.parse(xhr.responseText)
                        var tok = resp.refreshToken || resp.token || null
                        if (tok) {
                            if (restClient) restClient.setToken(tok)
                            loginPage.loginSucceeded(tok)
                            loginStatus.text = "Успешный вход"
                            loginStatus.color = "#4CAF50"
                        } else {
                            loginStatus.text = "Ошибка: токен не получен"
                            loginStatus.color = "red"
                        }
                    } catch (e) {
                        loginStatus.text = "Ошибка: неверный ответ сервера"
                        loginStatus.color = "red"
                    }
                } else {
                    loginStatus.text = "Ошибка входа: " + xhr.status
                    loginStatus.color = "red"
                }
            }
        }
        xhr.send(JSON.stringify({username: user, password: pass}))
    }
}
