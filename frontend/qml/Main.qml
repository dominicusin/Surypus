import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15

Window {
    visible: true
    width: 1200
    height: 800
    title: qsTr("Surypus")

    AppState {
        id: appState
    }

    RestClient {
        id: restClient
    }

    WsClient {
        id: wsClient
    }

    StackView {
        id: stackView
        anchors.fill: parent
        initialItem: Qt.resolvedUrl("screens/Persons.qml")
    }
}