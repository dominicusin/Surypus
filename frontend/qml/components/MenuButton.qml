import QtQuick 2.15
import QtQuick.Controls 2.15

Button {
    id: menuButton
    property Menu menu: null

    onClicked: {
        if (menuButton.menu) {
            menuButton.menu.popup(menuButton, 0, menuButton.height)
        }
    }
}
