import QtQuick 2.15
import QtQuick.Controls 2.15

Page {
  id: loginPage
  width: 360
  height: 240

  signal loginSucceeded(string token)

  Column {
    anchors.centerIn: parent
    spacing: 12

    Text {
      text: "Login to Surypus"
      font.pixelSize: 20
      horizontalAlignment: Text.AlignHCenter
      width: parent.width
    }

    TextField {
      id: usernameField
      placeholderText: "Username"
      width: parent.width * 0.8
      anchors.horizontalCenter: parent.horizontalCenter
    }
    TextField {
      id: passwordField
      placeholderText: "Password"
      echoMode: TextInput.Password
      width: parent.width * 0.8
      anchors.horizontalCenter: parent.horizontalCenter
    }
    Button {
      text: "Login"
      width: parent.width * 0.5
      anchors.horizontalCenter: parent.horizontalCenter
      onClicked: {
        login(usernameField.text, passwordField.text)
      }
    }
    Text {
      id: loginStatus
      color: "red"
      text: ""
      anchors.horizontalCenter: parent.horizontalCenter
    }
  }

  function login(user, pass) {
    // Simple placeholder using XMLHttpRequest; in real app use Qt Network access manager
    var xhr = new XMLHttpRequest();
    xhr.open("POST", "http://localhost:8080/api/v1/auth/login", true);
    xhr.setRequestHeader("Content-Type", "application/json");
    xhr.onreadystatechange = function() {
      if (xhr.readyState === 4) {
        if (xhr.status === 200) {
          try {
            var resp = JSON.parse(xhr.responseText);
            var tok = resp.refreshToken || resp.token || null;
            if (tok) {
              loginPage.loginSucceeded(tok)
              loginStatus.text = "Login successful";
            } else {
              loginStatus.text = "Login response missing token";
            }
          } catch (e) {
            loginStatus.text = "Invalid login response";
          }
        } else {
          loginStatus.text = "Login failed: " + xhr.status;
        }
      }
    }
    var payload = { username: user, password: pass };
    xhr.send(JSON.stringify(payload));
  }
}
