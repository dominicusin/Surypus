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

    SwipeView {
        id: view
        currentIndex: 0
        anchors.fill: parent

        // Login page
        Item {
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 16

                Text { text: "Surypus ERP"; font.pixelSize: 28; font.bold: true }
                TextField { id: loginUser; placeholderText: "Username"; Layout.preferredWidth: 250 }
                TextField { id: loginPass; placeholderText: "Password"; echoMode: TextInput.Password; Layout.preferredWidth: 250 }
                Button {
                    text: "Login"
                    Layout.preferredWidth: 250
                    onClicked: login()
                }
            }
        }

        // Dashboard page
        Item {
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                Text { text: "Dashboard"; font.pixelSize: 22; font.bold: true }

                // KPI cards row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    KpiCard { label: "Revenue"; value: kpiRevenue }
                    KpiCard { label: "Orders"; value: kpiOrders }
                    KpiCard { label: "Goods"; value: kpiGoods }
                    KpiCard { label: "Partners"; value: kpiPartners }
                }

                // Charts row
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 300
                    spacing: 12

                    ChartView {
                        title: "Revenue Trend"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        antialiasing: true
                        LineSeries {
                            id: revenueSeries
                            name: "Revenue"
                            XYPoint { x: 0; y: 0 }
                        }
                    }

                    ChartView {
                        title: "Order Status"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        antialiasing: true
                        PieSeries {
                            id: ordersPie
                            name: "Orders"
                        }
                    }
                }

                // Stock chart
                ChartView {
                    title: "Stock Summary"
                    Layout.fillWidth: true
                    Layout.preferredHeight: 200
                    antialiasing: true
                    BarSeries {
                        id: stockBars
                        name: "Stock"
                    }
                }
            }
        }
    }

    // KPI card component
    component KpiCard: Rectangle {
        property string label
        property string value

        Layout.fillWidth: true
        height: 80
        radius: 8
        color: "#f8f9fa"
        border.color: "#dee2e6"

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 4
            Text { text: value; font.pixelSize: 24; font.bold: true; Layout.alignment: Qt.AlignHCenter }
            Text { text: label; font.pixelSize: 12; color: "#6c757d"; Layout.alignment: Qt.AlignHCenter }
        }
    }

    property string kpiRevenue: "..."
    property string kpiOrders: "..."
    property string kpiGoods: "..."
    property string kpiPartners: "..."

    function login() {
        var xhr = new XMLHttpRequest();
        xhr.open("POST", apiBase + "/auth/login", true);
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    var resp = JSON.parse(xhr.responseText);
                    authToken = resp.accessToken;
                    view.currentIndex = 1;
                    loadDashboard();
                }
            }
        };
        xhr.send(JSON.stringify({ username: loginUser.text, password: loginPass.text }));
    }

    function loadDashboard() {
        fetchWithAuth(apiBase + "/dashboard", function(data) {
            kpiRevenue = data.kpiRevenue.toLocaleString();
            kpiOrders = data.kpiOrders.toString();
            kpiGoods = data.kpiActiveGoods.toString();
            kpiPartners = data.kpiPartners.toString();
        });

        fetchWithAuth(apiBase + "/dashboard/revenue", function(data) {
            revenueSeries.clear();
            for (var i = 0; i < data.length; i++) {
                revenueSeries.append(i, data[i].rpRevenue);
            }
        });

        fetchWithAuth(apiBase + "/dashboard/orders", function(data) {
            ordersPie.clear();
            for (var i = 0; i < data.length; i++) {
                ordersPie.append(data[i].osStatus, data[i].osCount);
            }
        });
    }

    function fetchWithAuth(url, callback) {
        var xhr = new XMLHttpRequest();
        xhr.open("GET", url, true);
        xhr.setRequestHeader("Authorization", "Bearer " + authToken);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                callback(JSON.parse(xhr.responseText));
            }
        };
        xhr.send();
    }
}
