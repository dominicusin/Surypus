import QtQuick 2.15
import QtQuick.Controls 2.15
import SurypusApiClient 1.0

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
    // Validate non-empty credentials (Threat T-15-08)
    if (!user || user.trim() === "" || !pass || pass.trim() === "") {
      loginStatus.text = "Please enter username and password"
      return
    }
    loginStatus.text = "Logging in..."
    ApiClient.login(user, pass)
  }

  Connections {
    target: ApiClient
    function onLoginSucceeded(token) {
      loginStatus.text = "Login successful"
      loginPage.loginSucceeded(token)
    }
    function onLoginFailed(error) {
      loginStatus.text = "Login failed: " + error
    }
  }
}
