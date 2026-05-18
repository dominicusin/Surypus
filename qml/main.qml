import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtCharts 2.15

ApplicationWindow {
    id: appWindow
    title: "Surypus ERP"
    width: 1200
    height: 800
    visible: true

    property string apiBase: "http://localhost:8080/api/v1"
    property string authToken: ""
    property string currentPage: "dashboard"

    SwipeView {
        id: view
        currentIndex: 0
        anchors.fill: parent

        // Login
        Item {
            ColumnLayout {
                anchors.centerIn: parent; spacing: 16
                Text { text: "Surypus ERP"; font.pixelSize: 28; font.bold: true }
                TextField { id: loginUser; placeholderText: "Username"; Layout.preferredWidth: 250 }
                TextField { id: loginPass; placeholderText: "Password"; echoMode: TextInput.Password; Layout.preferredWidth: 250 }
                Button { text: "Login"; Layout.preferredWidth: 250; onClicked: login() }
            }
        }

        // Main app with sidebar
        Item {
            RowLayout {
                anchors.fill: parent; spacing: 0

                // Sidebar nav
                Rectangle {
                    Layout.preferredWidth: 200; Layout.fillHeight: true; color: "#1a1a2e"
                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 8; spacing: 4
                        Repeater {
                            model: ["Dashboard","Deals","Pipeline","Goods","Bills","Reports","Settings"]
                            Button {
                                text: modelData; Layout.fillWidth: true
                                background: Rectangle { color: currentPage === modelData.toLowerCase() ? "#16213e" : "transparent"; radius: 4 }
                                onClicked: { currentPage = modelData.toLowerCase(); stack.pop(null); stack.push(pages[currentPage]) }
                            }
                        }
                    }
                }

                // Content area
                StackView {
                    id: stack; Layout.fillWidth: true; Layout.fillHeight: true
                    initialItem: dashboardPage
                }
            }
        }
    }

    Component { id: dashboardPage; DashboardPage {} }
    Component { id: dealsPage; DealsPage {} }
    Component { id: pipelinePage; PipelinePage {} }
    Component { id: goodsPage; GoodsPage {} }
    Component { id: billsPage; BillsPage {} }
    Component { id: reportsPage; ReportsPage {} }
    Component { id: settingsPage; SettingsPage {} }

    property var pages: ({
        dashboard: dashboardPage, deals: dealsPage, pipeline: pipelinePage,
        goods: goodsPage, bills: billsPage, reports: reportsPage, settings: settingsPage
    })

    function login() {
        var xhr = new XMLHttpRequest();
        xhr.open("POST", apiBase + "/auth/login", true);
        xhr.setRequestHeader("Content-Type","application/json");
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                authToken = JSON.parse(xhr.responseText).accessToken;
                view.currentIndex = 1;
            }
        };
        xhr.send(JSON.stringify({username: loginUser.text, password: loginPass.text}));
    }

    function apiGet(path, cb) {
        var xhr = new XMLHttpRequest();
        xhr.open("GET", apiBase + path, true);
        xhr.setRequestHeader("Authorization","Bearer " + authToken);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200)
                cb(JSON.parse(xhr.responseText));
        };
        xhr.send();
    }
}

// Dashboard page
import QtQuick 2.15 as QQ
QQ.Component {
    id: dashboardPage
    Item {
        ColumnLayout {
            anchors.fill: parent; anchors.margins: 16; spacing: 12
            Text { text: "Dashboard"; font.pixelSize: 22; font.bold: true }
            RowLayout {
                Layout.fillWidth: true; spacing: 12
                Repeater {
                    model: [
                        {label:"Revenue",value:kpiRevenue},
                        {label:"Orders",value:kpiOrders},
                        {label:"Goods",value:kpiGoods},
                        {label:"Partners",value:kpiPartners}
                    ]
                    Rectangle {
                        Layout.fillWidth: true; height: 80; radius: 8; color: "#f8f9fa"; border.color: "#dee2e6"
                        ColumnLayout {
                            anchors.centerIn: parent; spacing: 4
                            Text { text: modelData.value; font.pixelSize: 20; font.bold: true; Layout.alignment: Qt.AlignHCenter }
                            Text { text: modelData.label; font.pixelSize: 12; color: "#6c757d"; Layout.alignment: Qt.AlignHCenter }
                        }
                    }
                }
            }
        }
        property string kpiRevenue: "..."; property string kpiOrders: "..."
        property string kpiGoods: "..."; property string kpiPartners: "..."
        Component.onCompleted: {
            appWindow.apiGet("/dashboard", function(d) {
                kpiRevenue = d.kpiRevenue.toFixed(0); kpiOrders = d.kpiOrders; kpiGoods = d.kpiActiveGoods; kpiPartners = d.kpiPartners;
            });
        }
    }
}

// Stub pages for remaining modules
QQ.Component {
    id: dealsPage; Item {
        ColumnLayout { anchors.fill: parent; anchors.margins: 16
            Text { text: "CRM Deals"; font.pixelSize: 22; font.bold: true }
            Text { text: "Deal management — coming soon"; color: "#6c757d" }
        }
    }
}
QQ.Component {
    id: pipelinePage; Item {
        ColumnLayout { anchors.fill: parent; anchors.margins: 16
            Text { text: "Pipeline"; font.pixelSize: 22; font.bold: true }
        }
    }
}
QQ.Component {
    id: goodsPage; Item {
        ColumnLayout { anchors.fill: parent; anchors.margins: 16
            Text { text: "Goods"; font.pixelSize: 22; font.bold: true }
        }
    }
}
QQ.Component {
    id: billsPage; Item {
        ColumnLayout { anchors.fill: parent; anchors.margins: 16
            Text { text: "Bills"; font.pixelSize: 22; font.bold: true }
        }
    }
}
QQ.Component {
    id: reportsPage; Item {
        ColumnLayout { anchors.fill: parent; anchors.margins: 16
            Text { text: "Reports"; font.pixelSize: 22; font.bold: true }
            Button { text: "Generate P&L Report"; onClicked: appWindow.apiGet("/dashboard/revenue", function(d){}) }
        }
    }
}
QQ.Component {
    id: settingsPage; Item {
        ColumnLayout { anchors.fill: parent; anchors.margins: 16
            Text { text: "Settings"; font.pixelSize: 22; font.bold: true }
        }
    }
}
