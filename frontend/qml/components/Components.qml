import QtQuick 2.15
import QtQuick.Controls 2.15

QtObject {
    id: componentsModule

    property var card: Qt.resolvedUrl("Card.qml")
    property var statCard: Qt.resolvedUrl("StatCard.qml")
    property var navItem: Qt.resolvedUrl("NavItem.qml")
    property var quickActionButton: Qt.resolvedUrl("QuickActionButton.qml")
    property var taskDelegate: Qt.resolvedUrl("TaskDelegate.qml")
    property var notificationItem: Qt.resolvedUrl("NotificationItem.qml")
    property var reportTemplateCard: Qt.resolvedUrl("ReportTemplateCard.qml")
    property var locationCard: Qt.resolvedUrl("LocationCard.qml")
    property var kanbanColumn: Qt.resolvedUrl("KanbanColumn.qml")
    property var paginator: Qt.resolvedUrl("Paginator.qml")
    property var dateField: Qt.resolvedUrl("DateField.qml")
    property var menuButton: Qt.resolvedUrl("MenuButton.qml")
}
