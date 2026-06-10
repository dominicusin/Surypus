import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

RowLayout {
    id: paginator
    property int currentPage: 1
    property int totalPages: 1

    signal pageChanged(int page)

    Item { Layout.fillWidth: true }

    Button {
        text: "◀"
        enabled: paginator.currentPage > 1
        onClicked: pageChanged(paginator.currentPage - 1)
    }

    Label {
        text: paginator.currentPage + " / " + paginator.totalPages
        font.pixelSize: 12
        color: "#757575"
        leftPadding: 8
        rightPadding: 8
    }

    Button {
        text: "▶"
        enabled: paginator.currentPage < paginator.totalPages
        onClicked: pageChanged(paginator.currentPage + 1)
    }
}
