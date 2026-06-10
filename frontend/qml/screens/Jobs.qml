import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../components"

Page {
    id: jobsPage
    title: "Задачи"

    readonly property color primaryColor: "#1976D2"
    readonly property color successColor: "#4CAF50"
    readonly property color warningColor: "#FFC107"
    readonly property color errorColor: "#F44336"
    readonly property color backgroundColor: "#F5F5F5"

    background: Rectangle { color: backgroundColor }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24

        RowLayout {
            Button { text: "➕ Новая задача"; onClicked: console.log("New job") }
            ComboBox { model: ["Все", "Мои", "Неназначенные"] }
        }

        RowLayout {
            KanbanColumn { title: "К выполнению"; color: warningColor; model: pendingJobsModel }
            KanbanColumn { title: "В работе"; color: primaryColor; model: runningJobsModel }
            KanbanColumn { title: "Выполнено"; color: successColor; model: completedJobsModel }
            KanbanColumn { title: "Проблемы"; color: errorColor; model: failedJobsModel }
        }
    }

    ListModel { id: pendingJobsModel }
    ListModel { id: runningJobsModel }
    ListModel { id: completedJobsModel }
    ListModel { id: failedJobsModel }
}
