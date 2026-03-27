import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15

ApplicationWindow {
    id: root
    width: 1400
    height: 900
    minimumWidth: 1024
    minimumHeight: 768
    visible: true
    title: "Surypus ERP - Управление предприятием"

    // Color scheme
    property color primaryColor: "#0078D4"
    property color backgroundColor: "#F5F5F5"
    property color surfaceColor: "#FFFFFF"
    property color textColor: "#212121"
    property color secondaryTextColor: "#757575"
    property color borderColor: "#E0E0E0"
    property string apiBaseUrl: "http://localhost:8080/api/v1"
    property string jwtToken: ""
    property bool authenticated: false
    property string selectedReportSql: ""

    ListModel { id: registerModel }
    ListModel { id: counterModel }
    ListModel { id: reportModel }
    ListModel { id: techModel }
    ListModel { id: resourceModel }
    ListModel { id: jobModel }
    ListModel { id: personSummaryModel }
    ListModel { id: personSnapshotModel }
    ListModel { id: inventoryDocModel }
    ListModel { id: inventoryLineModel }
    ListModel { id: salaryChargeModel }
    ListModel { id: payrollSummaryModel }
    ListModel { id: payrollSnapshotModel }

    function httpRequest(method, path, payload, onSuccess, onError) {
        var xhr = new XMLHttpRequest()
        xhr.open(method, apiBaseUrl + path)
        xhr.setRequestHeader("Content-Type", "application/json")
        if (jwtToken.length > 0) {
            xhr.setRequestHeader("Authorization", "Bearer " + jwtToken)
        }
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status >= 200 && xhr.status < 300) {
                    var parsed = JSON.parse(xhr.responseText)
                    if (parsed.status === "ok") {
                        onSuccess(parsed)
                    } else if (onError) {
                        onError(xhr.status, parsed)
                    }
                } else if (onError) {
                    onError(xhr.status, xhr.responseText)
                }
            }
        }
        xhr.send(payload ? JSON.stringify(payload) : null)
    }

        function login() {
            httpRequest("POST", "/auth/login", { login: "admin", password: "admin" },
            function(resp) {
                jwtToken = resp.data.lrToken
                authenticated = true
                loadDocumentRegisters()
                loadDocumentCounters()
                loadReports()
                loadTechList()
                loadResourceList()
                loadReportSchedules()
                loadPersonSummary()
                loadPersonSnapshots()
            }, function(status, error) {
                console.log("Login failed", status, error)
            })
        }

        function ensureAuth() {
            if (jwtToken.length === 0) {
                login()
            } else {
                loadDocumentRegisters()
                loadDocumentCounters()
                loadReports()
                loadTechList()
                loadResourceList()
            }
        }

    function loadDocumentRegisters() {
        if (jwtToken.length === 0) { ensureAuth(); return }
        httpRequest("GET", "/documents/registers?limit=10&offset=0", null, function(resp) {
            updateRegisterModel(resp.data)
        }, function(status, err) {
            console.log("Register fetch failed", status, err)
        })
    }

    function loadDocumentCounters() {
        if (jwtToken.length === 0) { ensureAuth(); return }
        httpRequest("GET", "/documents/counters?limit=10&offset=0", null, function(resp) {
            updateCounterModel(resp.data)
        }, function(status, err) {
            console.log("Counter fetch failed", status, err)
        })
    }

    function loadReports() {
        if (jwtToken.length === 0) { ensureAuth(); return }
        httpRequest("GET", "/reports", null, function(resp) {
            updateReportModel(resp.data)
        }, function(status, err) {
            console.log("Reports fetch failed", status, err)
        })
    }

    function updateRegisterModel(items) {
        registerModel.clear()
        for (var i = 0; i < items.length; i++) {
            var entry = items[i]
            registerModel.append({
                person: entry.drPersonId !== undefined ? entry.drPersonId : "—",
                type: entry.drTypeId !== undefined ? entry.drTypeId : "—",
                number: entry.drNumber || "—",
                issue: entry.drIssueDate || "—",
                expiry: entry.drExpiryDate || "—"
            })
        }
    }

    function updateCounterModel(items) {
        counterModel.clear()
        for (var i = 0; i < items.length; i++) {
            var entry = items[i]
            counterModel.append({
                name: entry.docCounterName,
                prefix: entry.docCounterPrefix || "—",
                opKind: entry.docCounterOpKindId
            })
        }
    }

    property string reportFormName: ""
    property string reportFormCron: "0 0 * * *"
    property string reportFormParams: ""
    property string reportFormTemplate: ""
    property int selectedReportScheduleId: -1

    function updateReportModel(items) {
        reportModel.clear()
        for (var i = 0; i < items.length; i++) {
            var entry = items[i]
            reportModel.append({
                name: entry.name,
                title: entry.title,
                category: entry.category,
                description: entry.description,
                sql: entry.sql
            })
        }
        if (reportModel.count > 0) {
            selectedReportSql = reportModel.get(0).sql
            reportFormTemplate = reportModel.get(0).name
        }
    }

    function loadReportSchedules() {
        if (jwtToken.length === 0) { ensureAuth(); return }
        httpRequest("GET", "/reports/schedules", null, function(resp) {
            updateReportSchedules(resp.data)
        }, function(status, err) {
            console.log("Schedule fetch failed", status, err)
        })
    }

    function updateReportSchedules(items) {
        reportScheduleModel.clear()
        for (var i = 0; i < items.length; i++) {
            var entry = items[i]
            reportScheduleModel.append({
                id: entry.rsId,
                name: entry.rsName,
                report: entry.rsReport,
                cron: entry.rsCron,
                enabled: entry.rsEnabled,
                nextRun: entry.rsNextRun !== null ? entry.rsNextRun : "—"
            })
        }
    }

    function loadReportScheduleSnapshots(scheduleId) {
        if (jwtToken.length === 0) { ensureAuth(); return }
        httpRequest("GET", "/reports/schedules/" + scheduleId + "/snapshots", null, function(resp) {
            updateReportScheduleSnapshots(resp.data)
        }, function(status, err) {
            console.log("Snapshot fetch failed", status, err)
        })
    }

    function updateReportScheduleSnapshots(items) {
        reportScheduleSnapshotModel.clear()
        for (var i = 0; i < items.length; i++) {
            var entry = items[i]
            reportScheduleSnapshotModel.append({
                runId: entry.rssRunId,
                runAt: entry.rssRunAt,
                status: entry.rssStatus,
                message: entry.rssMessage !== null ? entry.rssMessage : "—"
            })
        }
    }

    function createReportSchedule() {
        if (jwtToken.length === 0) { ensureAuth(); return }
        var payload = {
            name: reportFormName,
            report: reportFormTemplate,
            cron: reportFormCron,
            params: reportFormParams === \"\" ? null : reportFormParams,
            enabled: true
        }
        httpRequest(\"POST\", \"/reports/schedules\", payload, function(resp) {
            reportFormName = \"\"
            reportFormCron = \"0 0 * * *\"
            reportFormParams = \"\"
            loadReportSchedules()
        }, function(status, err) {
            console.log(\"Schedule create failed\", status, err)
        })
    }

    function runReportSchedule(scheduleId) {
        if (jwtToken.length === 0) { ensureAuth(); return }
        httpRequest(\"POST\", \"/reports/schedules/\" + scheduleId + \"/run\", null, function(resp) {
            console.log(\"Scheduled report enqueued\", resp.data)
            loadReportScheduleSnapshots(scheduleId)
        }, function(status, err) {
            console.log(\"Failed to enqueue report\", status, err)
        })
    }

    function loadTechList() {
        if (jwtToken.length === 0) { ensureAuth(); return }
        httpRequest("GET", "/production/tech", null, function(resp) {
            updateTechModel(resp.data)
        }, function(status, err) {
            console.log("Tech fetch failed", status, err)
        })
    }

    function loadResourceList() {
        if (jwtToken.length === 0) { ensureAuth(); return }
        httpRequest("GET", "/production/resources", null, function(resp) {
            updateResourceModel(resp.data)
        }, function(status, err) {
            console.log("Resources fetch failed", status, err)
        })
    }

    function updateTechModel(items) {
        techModel.clear()
        for (var i = 0; i < items.length; i++) {
            var entry = items[i]
            techModel.append({
                name: entry.name,
                goodsId: entry.goodsId !== undefined ? entry.goodsId : "—",
                version: entry.version,
                kind: entry.kind,
                flags: entry.flags
            })
        }
    }

    function updateResourceModel(items) {
        resourceModel.clear()
        for (var i = 0; i < items.length; i++) {
            var entry = items[i]
            resourceModel.append({
                code: entry.code,
                name: entry.name,
                kind: entry.kind,
                capacity: entry.capacity !== null ? entry.capacity : "—",
                cost: entry.costPerHour !== null ? entry.costPerHour : "—",
                hours: entry.availableHours !== null ? entry.availableHours : "—"
            })
        }
    }

    property int selectedInventoryDocId: -1
    property var selectedInventorySummary: null
    property string payrollSummaryFrom: Qt.formatDate(new Date(new Date().getFullYear(), new Date().getMonth(), 1), "yyyy-MM-dd")
    property string payrollSummaryTo: Qt.formatDate(new Date(), "yyyy-MM-dd")
    property string payrollSnapshotFrom: payrollSummaryFrom
    property string payrollSnapshotTo: payrollSummaryTo

    function loadInventoryDocs() {
        if (jwtToken.length === 0) { ensureAuth(); return }
        httpRequest("GET", "/inventory?limit=20&offset=0", null, function(resp) {
            inventoryDocModel.clear()
            for (var i = 0; i < resp.data.length; i++) {
                var doc = resp.data[i]
                inventoryDocModel.append({
                    id: doc.invDocId,
                    code: doc.invDocCode,
                    date: doc.invDocDate,
                    warehouse: doc.invDocWarehouseId,
                    status: doc.invDocStatus,
                    memo: doc.invDocMemo || "—"
                })
            }
        }, function(status, err) {
            console.log("Inventory fetch failed", status, err)
        })
    }

    function loadInventoryDetail(docId) {
        if (jwtToken.length === 0) { ensureAuth(); return }
        selectedInventoryDocId = docId
        httpRequest("GET", "/inventory/" + docId, null, function(resp) {
            inventoryLineModel.clear()
            if (resp.data && resp.data.iddLines) {
                for (var i = 0; i < resp.data.iddLines.length; i++) {
                    var line = resp.data.iddLines[i]
                    inventoryLineModel.append({
                        goods: line.ilGoodsId,
                        expected: line.ilExpectedQtty,
                        actual: line.ilActualQtty,
                        diff: line.ilDiffQtty,
                        price: line.ilPrice
                    })
                }
            }
            selectedInventorySummary = resp.data && resp.data.iddSummary ? resp.data.iddSummary : null
        }, function(status, err) {
            console.log("Inventory detail failed", status, err)
        })
    }

    function loadSalaryCharges() {
        if (jwtToken.length === 0) { ensureAuth(); return }
        httpRequest("GET", "/hr/charges", null, function(resp) {
            salaryChargeModel.clear()
            for (var i = 0; i < resp.data.length; i++) {
                var charge = resp.data[i]
                salaryChargeModel.append({
                    id: charge.scId,
                    name: charge.scName,
                    code: charge.scCode || "—",
                    flags: charge.scFlags
                })
            }
        }, function(status, err) {
            console.log("Salary charge fetch failed", status, err)
        })
    }

    function loadPayrollSummary() {
        if (jwtToken.length === 0) { ensureAuth(); return }
        var from = payrollSummaryFrom
        var to = payrollSummaryTo
        httpRequest("GET", "/hr/payrolls/summary?from=" + from + "&to=" + to, null, function(resp) {
            payrollSummaryModel.clear()
            for (var i = 0; i < resp.data.length; i++) {
                var entry = resp.data[i]
                payrollSummaryModel.append({
                    name: entry.ssEmployeeName,
                    position: entry.ssPosition,
                    total: entry.ssTotal,
                    employeeId: entry.ssEmployeeId
                })
            }
        }, function(status, err) {
            console.log("Payroll summary fetch failed", status, err)
        })
    }

    function loadPayrollSnapshots() {
        if (jwtToken.length === 0) { ensureAuth(); return }
        httpRequest("GET", "/hr/payrolls/snapshots", null, function(resp) {
            payrollSnapshotModel.clear()
            for (var i = 0; i < resp.data.length; i++) {
                var entry = resp.data[i]
                var summaryCount = entry.psrSummary ? entry.psrSummary.length : 0
                payrollSnapshotModel.append({
                    id: entry.psrId,
                    period: entry.psrPeriodStart + " — " + entry.psrPeriodEnd,
                    created: entry.psrCreatedAt,
                    count: summaryCount,
                    details: summaryCount > 0 ? JSON.stringify(entry.psrSummary.slice(0, 3)) : "[]"
                })
            }
        }, function(status, err) {
            console.log("Payroll snapshot fetch failed", status, err)
        })
    }

    function triggerPayrollSnapshot() {
        if (jwtToken.length === 0) { ensureAuth(); return }
        var payload = { periodStart: payrollSnapshotFrom, periodEnd: payrollSnapshotTo }
        httpRequest("POST", "/hr/payrolls/snapshots", payload, function(resp) {
            console.log("Payroll snapshot job enqueued", resp.data)
            loadPayrollSnapshots()
        }, function(status, err) {
            console.log("Failed to enqueue payroll snapshot", status, err)
        })
    }

    function loadJobs() {
        if (jwtToken.length === 0) { ensureAuth(); return }
        httpRequest("GET", "/jobs", null, function(resp) {
            updateJobModel(resp.data)
        }, function(status, err) {
            console.log("Jobs fetch failed", status, err)
        })
    }

    function loadPersonSummary() {
        if (jwtToken.length === 0) { ensureAuth(); return }
        httpRequest("GET", "/persons/summary", null, function(resp) {
            updatePersonSummary(resp.data)
        }, function(status, err) {
            console.log("Person summary failed", status, err)
        })
    }

    function updatePersonSummary(items) {
        personSummaryModel.clear()
        for (var i = 0; i < items.length; i++) {
            var entry = items[i]
            personSummaryModel.append({
                status: entry.status,
                category: entry.category,
                total: entry.total,
                creditLimit: entry.totalCreditLimit,
                avgDiscount: entry.avgDiscount
            })
        }
    }

    function loadPersonSnapshots() {
        if (jwtToken.length === 0) { ensureAuth(); return }
        httpRequest("GET", "/persons/summary/snapshots", null, function(resp) {
            updatePersonSnapshots(resp.data)
        }, function(status, err) {
            console.log("Snapshots fetch failed", status, err)
        })
    }

    function updatePersonSnapshots(items) {
        personSnapshotModel.clear()
        for (var i = 0; i < items.length; i++) {
            var entry = items[i]
            personSnapshotModel.append({
                runId: entry.pssRunId,
                runAt: entry.pssRunAt,
                status: entry.pssStatus,
                category: entry.pssCategory,
                total: entry.pssTotal,
                creditLimit: entry.pssCreditLimit,
                avgDiscount: entry.pssAvgDiscount
            })
        }
    }

    function triggerPersonSnapshot() {
        if (jwtToken.length === 0) { ensureAuth(); return }
        httpRequest("POST", "/persons/summary/snapshots", null, function(resp) {
            console.log("Snapshot taken", resp.data)
            loadPersonSnapshots()
        }, function(status, err) {
            console.log("Snapshot trigger failed", status, err)
        })
    }

    function updateJobModel(items) {
        jobModel.clear()
        for (var i = 0; i < items.length; i++) {
            var entry = items[i]
            var deps = "—"
            if (entry.jobDependencies && entry.jobDependencies.length > 0) {
                deps = entry.jobDependencies.join(", ")
            }
            jobModel.append({
                id: entry.jobId,
                code: entry.jobCode,
                name: entry.jobName,
                type: entry.jobType,
                status: entry.jobStatus,
                priority: entry.jobPriority,
                scheduled: entry.jobScheduledAt !== null ? entry.jobScheduledAt : "—",
                created: entry.jobCreatedAt,
                message: entry.jobErrorMessage !== null ? entry.jobErrorMessage : "—"
                , dependencies: deps
            })
        }
    }

    Timer {
        id: authTimer
        interval: 100
        running: true
        repeat: false
        onTriggered: ensureAuth()
    }

    header: ToolBar {
        id: toolbar
        background: Rectangle { color: surfaceColor }

        RowLayout {
            anchors.fill: parent
            spacing: 8

            // Logo
            Text {
                text: "📊"
                font.pixelSize: 24
            }

            Text {
                text: "Surypus"
                font.bold: true
                font.pixelSize: 18
                color: primaryColor
            }

            Rectangle { Layout.fillWidth: true }

            // Search
            TextField {
                placeholderText: "Поиск..."
                width: 200
                background: Rectangle {
                    radius: 4
                    color: backgroundColor
                }
            }

            // User menu
            ToolButton {
                text: "👤 Администратор"
            }
        }
    }

    // Main content
    RowLayout {
        anchors.fill: parent
        spacing: 0

        // Navigation sidebar
        Rectangle {
            width: 250
            Layout.fillHeight: true
            color: surfaceColor
            border.right: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 4

                // Navigation items
                NavigationItem {
                    icon: "📋"
                    text: "Обзор"
                    selected: true
                }

                NavigationItem {
                    icon: "📦"
                    text: "Товары"
                }

                NavigationItem {
                    icon: "📄"
                    text: "Документы"
                }

                NavigationItem {
                    icon: "👥"
                    text: "Контрагенты"
                    onActivate: contentStack.push(personSummaryPage)
                }

                NavigationItem {
                    icon: "🏭"
                    text: "Склады"
                    onActivate: {
                        loadInventoryDocs()
                        contentStack.push(inventoryPage)
                    }
                }

                NavigationItem {
                    icon: "📊"
                    text: "Отчёты"
                    onActivate: contentStack.push(reportPage)
                }

                NavigationItem {
                    icon: "🧠"
                    text: "Jobs"
                    onActivate: contentStack.push(jobsPage)
                }

                Rectangle { Layout.fillHeight: true }

                NavigationItem {
                    icon: "📊"
                    text: "Отчёты"
                    onActivate: contentStack.push(reportsPage)
                }

                NavigationItem {
                    icon: "⚙️"
                    text: "Настройки"
                    onActivate: contentStack.push(settingsPage)
                }
                NavigationItem {
                    icon: "💼"
                    text: "Кадры"
                    onActivate: {
                        loadSalaryCharges()
                        loadPayrollSummary()
                        loadPayrollSnapshots()
                        contentStack.push(hrPage)
                    }
                }
            }
        }

        // Content area
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: backgroundColor

            StackView {
                id: contentStack
                anchors.fill: parent
                anchors.margins: 16

                initialItem: DashboardPage {}
            }
        }
    }

    // Status bar
    footer: StatusBar {
        background: Rectangle { color: surfaceColor }

        RowLayout {
            anchors.fill: parent

            Text {
                text: "Готов"
                color: secondaryTextColor
            }

            Rectangle { Layout.fillWidth: true }

            Text {
                text: "Подключение: localhost:5433"
                color: secondaryTextColor
            }

            Text {
                text: " | Пользователь: admin"
                color: secondaryTextColor
            }
        }
    }
}

// Navigation item component
Component {
    id: navItem

    Rectangle {
        radius: 4
        color: "transparent"
        property var onActivate

        RowLayout {
            spacing: 12
            padding: 10

            Text {
                text: icon
                font.pixelSize: 18
            }

            Text {
                text: text
                font.pixelSize: 14
                color: "#212121"
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                parent.color = "#E3F2FD"
                if (typeof onActivate === "function") onActivate()
            }
            onPressAndHold: {
                parent.color = "#BBDEFB"
            }
        }
    }
}

// Dashboard page
Component {
    id: dashboardPage

    ColumnLayout {
        spacing: 16

        // Title
        Text {
            text: "Обзор"
            font.pixelSize: 24
            font.bold: true
            color: textColor
        }

        // Stats cards
        GridLayout {
            columns: 4
            rowSpacing: 16
            columnSpacing: 16

            StatCard {
                title: "Продажи сегодня"
                value: "125 000 ₽"
                color: "#4CAF50"
            }

            StatCard {
                title: "Заказов сегодня"
                value: "15"
                color: "#2196F3"
            }

            StatCard {
                title: "Товаров в наличии"
                value: "1 234"
                color: "#FF9800"
            }

            StatCard {
                title: "Ниже минимума"
                value: "12"
                color: "#F44336"
            }
        }

        // Charts row
        RowLayout {
            spacing: 16
            Layout.fillWidth: true

            Rectangle {
                Layout.fillWidth: true
                height: 200
                color: surfaceColor
                radius: 8
                border.color: borderColor

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16

                    Text {
                        text: "Продажи по дням"
                        font.bold: true
                        font.pixelSize: 14
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 8

                        Rectangle {
                            Layout.fillHeight: true
                            Layout.fillWidth: true
                            color: "#E3F2FD"
                            radius: 4

                            Column {
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 8
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 4

                                Text {
                                    text: "Пн"
                                    font.pixelSize: 10
                                    color: secondaryTextColor
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillHeight: true
                            Layout.fillWidth: true
                            color: "#BBDEFB"
                            radius: 4

                            Column {
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 8
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 4

                                Text {
                                    text: "Вт"
                                    font.pixelSize: 10
                                    color: secondaryTextColor
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillHeight: true
                            Layout.fillWidth: true
                            color: "#90CAF9"
                            radius: 4

                            Column {
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 8
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 4

                                Text {
                                    text: "Ср"
                                    font.pixelSize: 10
                                    color: secondaryTextColor
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillHeight: true
                            Layout.fillWidth: true
                            color: "#64B5F6"
                            radius: 4

                            Column {
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 8
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 4

                                Text {
                                    text: "Чт"
                                    font.pixelSize: 10
                                    color: secondaryTextColor
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillHeight: true
                            Layout.fillWidth: true
                            color: "#42A5F5"
                            radius: 4

                            Column {
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 8
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 4

                                Text {
                                    text: "Пт"
                                    font.pixelSize: 10
                                    color: secondaryTextColor
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillHeight: true
                            Layout.fillWidth: true
                            color: "#1E88E5"
                            radius: 4

                            Column {
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 8
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 4

                                Text {
                                    text: "Сб"
                                    font.pixelSize: 10
                                    color: secondaryTextColor
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 200
                color: surfaceColor
                radius: 8
                border.color: borderColor

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16

                    Text {
                        text: "Топ товаров"
                        font.bold: true
                        font.pixelSize: 14
                    }

                    ColumnLayout {
                        spacing: 8

                        RowLayout {
                            Text { text: "1."; color: secondaryTextColor; width: 20 }
                            Text { text: "Стройматериалы"; Layout.fillWidth: true }
                            Text { text: "45 000 ₽"; color: primaryColor }
                        }

                        RowLayout {
                            Text { text: "2."; color: secondaryTextColor; width: 20 }
                            Text { text: "Инструменты"; Layout.fillWidth: true }
                            Text { text: "32 500 ₽"; color: primaryColor }
                        }

                        RowLayout {
                            Text { text: "3."; color: secondaryTextColor; width: 20 }
                            Text { text: "Крепёж"; Layout.fillWidth: true }
                            Text { text: "18 200 ₽"; color: primaryColor }
                        }

                        RowLayout {
                            Text { text: "4."; color: secondaryTextColor; width: 20 }
                            Text { text: "Смеси"; Layout.fillWidth: true }
                            Text { text: "12 800 ₽"; color: primaryColor }
                        }
                    }
                }
            }
        }

        // Recent documents
        Rectangle {
            Layout.fillWidth: true
            height: 300
            color: surfaceColor
            radius: 8

            ColumnLayout {
                anchors.margins: 16
                anchors.fill: parent

                Text {
                    text: "Последние документы"
                    font.pixelSize: 16
                    font.bold: true
                }

                TableView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    columnSpacing: 1
                    rowSpacing: 1

                    TableViewColumn { title: "Номер"; width: 100 }
                    TableViewColumn { title: "Дата"; width: 100 }
                    TableViewColumn { title: "Тип"; width: 150 }
                    TableViewColumn { title: "Контрагент"; width: 200 }
                    TableViewColumn { title: "Сумма"; width: 120 }
                    TableViewColumn { title: "Статус"; width: 100 }
                }
            }
        }

        RowLayout {
            spacing: 12
            Layout.alignment: Qt.AlignRight

            Button {
                text: "Перейти к документам"
                onClicked: contentStack.push(documentPage)
            }

            Button {
                text: "Перейти к отчётам"
                onClicked: contentStack.push(reportPage)
            }

            Button {
                text: "Производство"
                onClicked: contentStack.push(productionPage)
            }
        }
    }
}

// Stat card component
Component {
    id: statCard

    Rectangle {
        width: 200
        height: 120
        color: surfaceColor
        radius: 8
        property string title: ""
        property string value: ""
        property color color: "#0078D4"

        ColumnLayout {
            anchors.margins: 16
            anchors.fill: parent

            Text {
                text: title
                color: "#757575"
                font.pixelSize: 12
            }

            Text {
                text: value
                color: color
                font.pixelSize: 28
                font.bold: true
                Layout.alignment: Qt.AlignCenter
            }
        }
    }
}

Component {
    id: documentPage

    ScrollView {
        anchors.fill: parent
        ColumnLayout {
            width: parent.width
            spacing: 16

            Text {
                text: "Регистры документов"
                font.pixelSize: 22
                font.bold: true
            }

            Rectangle {
                Layout.fillWidth: true
                color: surfaceColor
                radius: 8
                border.color: borderColor
                border.width: 1

                ColumnLayout {
                    anchors.margins: 12

                    RowLayout {
                        spacing: 8
                        Button {
                            text: "Обновить регистры"
                            onClicked: loadDocumentRegisters()
                        }
                        Button {
                            text: "Назад на обзор"
                            onClicked: contentStack.pop()
                        }
                    }

                    TableView {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 220
                        model: registerModel
                        clip: true
                        TableViewColumn { role: "number"; title: "Номер документа"; width: 220 }
                        TableViewColumn { role: "person"; title: "Контрагент"; width: 120 }
                        TableViewColumn { role: "type"; title: "Тип"; width: 120 }
                        TableViewColumn { role: "issue"; title: "Дата выдачи"; width: 120 }
                        TableViewColumn { role: "expiry"; title: "Дата окончания"; width: 120 }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                color: surfaceColor
                radius: 8
                border.color: borderColor
                border.width: 1

                ColumnLayout {
                    anchors.margins: 12
                    spacing: 12

                    RowLayout {
                        spacing: 8
                        Text {
                            text: "Счётчики документов"
                            font.pixelSize: 18
                            font.bold: true
                        }
                        Button {
                            text: "Обновить счётчики"
                            onClicked: loadDocumentCounters()
                        }
                    }

                    TableView {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 180
                        model: counterModel
                        clip: true
                        TableViewColumn { role: "name"; title: "Имя"; width: 200 }
                        TableViewColumn { role: "prefix"; title: "Префикс"; width: 120 }
                        TableViewColumn { role: "opKind"; title: "Вид операции"; width: 150 }
                    }
                }
            }
        }
    }
}

Component {
    id: inventoryPage

    ScrollView {
        anchors.fill: parent
        ColumnLayout {
            width: parent.width
            spacing: 16

            RowLayout {
                spacing: 8
                Text {
                    text: "Инвентаризации"
                    font.pixelSize: 22
                    font.bold: true
                }
                Button {
                    text: "Обновить"
                    onClicked: loadInventoryDocs()
                }
                Button {
                    text: "Назад"
                    onClicked: contentStack.pop()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                color: surfaceColor
                radius: 8
                border.color: borderColor
                border.width: 1

                ColumnLayout {
                    anchors.margins: 12

                    TableView {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 240
                        model: inventoryDocModel
                        clip: true
                        TableViewColumn { role: "code"; title: "Код"; width: 120 }
                        TableViewColumn { role: "date"; title: "Дата"; width: 120 }
                        TableViewColumn { role: "warehouse"; title: "Склад"; width: 140 }
                        TableViewColumn { role: "status"; title: "Статус"; width: 120 }
                        TableViewColumn { role: "memo"; title: "Примечание"; width: 200 }
                        onActivated: loadInventoryDetail(inventoryDocModel.get(row).id)
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                color: surfaceColor
                radius: 8
                border.color: borderColor
                border.width: 1

                ColumnLayout {
                    anchors.margins: 12
                    spacing: 4

                    Text {
                        text: "Строки выбранной инвентаризации"
                        font.bold: true
                        font.pixelSize: 16
                    }

                    TableView {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 180
                        model: inventoryLineModel
                        clip: true
                        TableViewColumn { role: "goods"; title: "Товар"; width: 120 }
                        TableViewColumn { role: "expected"; title: "Учёт"; width: 120 }
                        TableViewColumn { role: "actual"; title: "Факт"; width: 120 }
                        TableViewColumn { role: "diff"; title: "Отклонение"; width: 120 }
                        TableViewColumn { role: "price"; title: "Цена"; width: 100 }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                color: surfaceColor
                radius: 8
                border.color: borderColor
                border.width: 1

                ColumnLayout {
                    anchors.margins: 12
                    spacing: 8

                    Text {
                        text: "Сводка"
                        font.bold: true
                        font.pixelSize: 16
                    }
                    RowLayout {
                        spacing: 16
                        Text { text: "Сумма план: " + (selectedInventorySummary ? selectedInventorySummary.isSummaryBooked : "—") }
                        Text { text: "Сумма факт: " + (selectedInventorySummary ? selectedInventorySummary.isSummaryFact : "—") }
                        Text { text: "Разница: " + (selectedInventorySummary ? selectedInventorySummary.isSummaryDiff : "—") }
                    }
                    RowLayout {
                        spacing: 16
                        Text { text: "Излишков: " + (selectedInventorySummary ? selectedInventorySummary.isSummarySurplus : "—") }
                        Text { text: "Недостач: " + (selectedInventorySummary ? selectedInventorySummary.isSummaryShortage : "—") }
                        Text { text: "Строк: " + (selectedInventorySummary ? selectedInventorySummary.isSummaryItemCount : "—") }
                    }
                    Text {
                        text: "Выбранный документ ID: " + (selectedInventoryDocId === -1 ? "—" : selectedInventoryDocId)
                    }
                }
            }
        }
    }
}

Component {
    id: reportPage

    ScrollView {
        anchors.fill: parent
        ColumnLayout {
            width: parent.width
            spacing: 16

            Text {
                text: "Отчётная система"
                font.pixelSize: 22
                font.bold: true
            }

            Button {
                text: "Обновить список отчётов"
                onClicked: loadReports()
            }

            ListView {
                Layout.fillWidth: true
                Layout.preferredHeight: 260
                model: reportModel
                spacing: 4
                delegate: Rectangle {
                    width: parent.width
                    height: 70
                    color: index % 2 === 0 ? "#FFFFFF" : "#F0F0F0"
                    border.color: borderColor
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8

                        Text { text: model.title; font.bold: true }
                        Text { text: model.description; font.pixelSize: 12; color: secondaryTextColor; elide: Text.ElideRight }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.selectedReportSql = model.sql
                        }
                    }
                }
            }

            TextArea {
                Layout.fillWidth: true
                Layout.preferredHeight: 220
                readOnly: true
                wrapMode: TextArea.WrapAnywhere
                text: selectedReportSql
                font.family: "monospace"
            }

            Rectangle {
                Layout.fillWidth: true
                color: surfaceColor
                radius: 8
                border.color: borderColor
                border.width: 1

                ColumnLayout {
                    anchors.margins: 12
                    spacing: 12

                    Text {
                        text: "Планировщик отчётов"
                        font.pixelSize: 18
                        font.bold: true
                    }

                    RowLayout {
                        spacing: 8
                        Layout.fillWidth: true
                        TextField {
                            placeholderText: "Название расписания"
                            Layout.fillWidth: true
                            text: reportFormName
                            onTextChanged: reportFormName = text
                        }
                        TextField {
                            placeholderText: "Cron"
                            width: 180
                            text: reportFormCron
                            onTextChanged: reportFormCron = text
                        }
                        ComboBox {
                            model: reportModel
                            textRole: "title"
                            currentIndex: 0
                            onCurrentIndexChanged: {
                                if (index >= 0 && index < reportModel.count)
                                    reportFormTemplate = reportModel.get(index).name
                            }
                        }
                        Button {
                            text: "Создать"
                            onClicked: createReportSchedule()
                        }
                    }

                    TextArea {
                        placeholderText: "Параметры (JSON)"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 100
                        text: reportFormParams
                        onTextChanged: reportFormParams = text
                    }

                    TableView {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 200
                        model: reportScheduleModel
                        clip: true
                        TableViewColumn { role: "name"; title: "Название"; width: 220 }
                        TableViewColumn { role: "report"; title: "Шаблон"; width: 160 }
                        TableViewColumn { role: "cron"; title: "Cron"; width: 160 }
                        TableViewColumn { role: "enabled"; title: "Вкл."; width: 80 }
                        TableViewColumn { role: "nextRun"; title: "След. запуск"; width: 200 }
                        onActivated: {
                            selectedReportScheduleId = model.id
                            loadReportScheduleSnapshots(selectedReportScheduleId)
                        }
                    }

                    RowLayout {
                        spacing: 8
                        Button {
                            text: "Запустить сейчас"
                            enabled: selectedReportScheduleId !== -1
                            onClicked: runReportSchedule(selectedReportScheduleId)
                        }
                        Button {
                            text: "Обновить расписания"
                            onClicked: loadReportSchedules()
                        }
                    }

                    TableView {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 200
                        model: reportScheduleSnapshotModel
                        clip: true
                        TableViewColumn { role: "runId"; title: "Run UUID"; width: 220 }
                        TableViewColumn { role: "runAt"; title: "Время"; width: 200 }
                        TableViewColumn { role: "status"; title: "Статус"; width: 120 }
                        TableViewColumn { role: "message"; title: "Сообщение"; width: 260 }
                    }
                }
            }
        }
    }
}

Component {
    id: personSummaryPage

    ScrollView {
        anchors.fill: parent
        ColumnLayout {
            width: parent.width
            spacing: 16

            Text {
                text: "Контрагенты: KPI и Snapshot"
                font.pixelSize: 22
                font.bold: true
            }

            RowLayout {
                spacing: 8
                Button {
                    text: "Обновить KPI"
                    onClicked: loadPersonSummary()
                }
                Button {
                    text: "Снять snapshot"
                    onClicked: triggerPersonSnapshot()
                }
                Button {
                    text: "Обновить snapshots"
                    onClicked: loadPersonSnapshots()
                }
                Button {
                    text: "Назад"
                    onClicked: contentStack.pop()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                color: surfaceColor
                radius: 8
                border.color: borderColor
                border.width: 1

                ColumnLayout {
                    anchors.margins: 12
                    spacing: 12

                    Text {
                        text: "Агрегация по статусам и категориям"
                        font.pixelSize: 18
                        font.bold: true
                    }

                    TableView {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 220
                        model: personSummaryModel
                        clip: true
                        TableViewColumn { role: "status"; title: "Статус"; width: 100 }
                        TableViewColumn { role: "category"; title: "Категория"; width: 120 }
                        TableViewColumn { role: "total"; title: "Кол-во"; width: 120 }
                        TableViewColumn { role: "creditLimit"; title: "Кредитный лимит"; width: 180 }
                        TableViewColumn { role: "avgDiscount"; title: "Средняя скидка"; width: 160 }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                color: surfaceColor
                radius: 8
                border.color: borderColor
                border.width: 1

                ColumnLayout {
                    anchors.margins: 12
                    spacing: 12

                    Text {
                        text: "История snapshots"
                        font.pixelSize: 18
                        font.bold: true
                    }

                    TableView {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 280
                        model: personSnapshotModel
                        clip: true
                        TableViewColumn { role: "runId"; title: "Run UUID"; width: 220 }
                        TableViewColumn { role: "runAt"; title: "Время"; width: 200 }
                        TableViewColumn { role: "status"; title: "Статус"; width: 120 }
                        TableViewColumn { role: "category"; title: "Категория"; width: 120 }
                        TableViewColumn { role: "total"; title: "Кол-во"; width: 120 }
                        TableViewColumn { role: "creditLimit"; title: "Кредитный лимит"; width: 180 }
                        TableViewColumn { role: "avgDiscount"; title: "Средняя скидка"; width: 160 }
                    }
                }
            }
        }
    }
}

Component {
    id: jobsPage

    ScrollView {
        anchors.fill: parent
        ColumnLayout {
            width: parent.width
            spacing: 16

            property int selectedJobId: -1
            property string dependencyReason: ""

            RowLayout {
                spacing: 8
                Text {
                    text: "Очередь jobs / ETL"
                    font.pixelSize: 22
                    font.bold: true
                }
                Button {
                    text: "Обновить очередь"
                    onClicked: loadJobs()
                }
                Button {
                    text: "Назад"
                    onClicked: contentStack.pop()
                }
            }

            RowLayout {
                spacing: 8
                anchors.margins: 8
                Text {
                    text: "Выбранная задача: " + (selectedJobId === -1 ? "—" : selectedJobId)
                    font.pixelSize: 14
                }
                TextField {
                    id: dependencyField
                    placeholderText: "ID зависимости"
                    width: 140
                    inputMethodHints: Qt.ImhDigitsOnly
                }
                TextField {
                    id: dependencyTypeField
                    placeholderText: "Тип зависимости (BLOCKS/WAITS_FOR)"
                    width: 220
                }
                Button {
                    text: "Добавить зависимость"
                    onClicked: createDependency()
                }
            }

            function createDependency() {
                if (selectedJobId === -1) {
                    console.log("Выберите задачу для добавления зависимости")
                    return
                }
                var target = parseInt(dependencyField.text, 10)
                if (isNaN(target)) {
                    console.log("Неверный ID зависимости")
                    return
                }
                var payload = {
                    dependsOnId: target,
                    dependencyType: dependencyTypeField.text || "BLOCKS"
                }
                httpRequest("POST", "/jobs/" + selectedJobId + "/dependencies", payload, function(resp) {
                    loadJobs()
                    dependencyField.text = ""
                    dependencyTypeField.text = ""
                }, function(status, err) {
                    console.log("Не удалось добавить зависимость", status, err)
                })
            }

            Rectangle {
                Layout.fillWidth: true
                color: surfaceColor
                radius: 8
                border.color: borderColor
                border.width: 1

                TableView {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 320
                    model: jobModel
                    clip: true
                    TableViewColumn { role: "code"; title: "Код"; width: 140 }
                    TableViewColumn { role: "name"; title: "Название"; width: 200 }
                    TableViewColumn { role: "type"; title: "Тип"; width: 120 }
                    TableViewColumn { role: "status"; title: "Статус"; width: 100 }
                    TableViewColumn { role: "priority"; title: "Приоритет"; width: 80 }
                    TableViewColumn { role: "scheduled"; title: "Запланировано"; width: 180 }
                    TableViewColumn { role: "created"; title: "Создано"; width: 180 }
                    TableViewColumn { role: "message"; title: "Последние ошибки"; width: 200 }
                    TableViewColumn { role: "dependencies"; title: "Зависимости"; width: 200 }
                    onActivated: jobsPage.selectedJobId = jobModel.get(row).id
                }
            }
        }
    }
}

Component {
    id: hrPage

    ScrollView {
        anchors.fill: parent
        ColumnLayout {
            width: parent.width
            spacing: 16

            RowLayout {
                spacing: 8
                Text {
                    text: "Кадры и зарплата"
                    font.pixelSize: 22
                    font.bold: true
                }
                Button {
                    text: "Назад"
                    onClicked: contentStack.pop()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                color: surfaceColor
                radius: 8
                border.color: borderColor
                border.width: 1
                ColumnLayout {
                    anchors.margins: 12
                    spacing: 8
                    RowLayout {
                        spacing: 8
                        Text {
                            text: "Зарплатные начисления"
                            font.pixelSize: 18
                            font.bold: true
                        }
                        Button { text: "Обновить"; onClicked: loadSalaryCharges() }
                    }
                    TableView {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 180
                        model: salaryChargeModel
                        clip: true
                        TableViewColumn { role: "name"; title: "Наименование"; width: 240 }
                        TableViewColumn { role: "code"; title: "Код"; width: 140 }
                        TableViewColumn { role: "flags"; title: "Флаги"; width: 120 }
                    }
                    RowLayout {
                        spacing: 8
                        TextField { id: chargeNameField; placeholderText: "Название"; width: 200 }
                        TextField { id: chargeCodeField; placeholderText: "Код"; width: 120 }
                        TextField { id: chargeFlagsField; placeholderText: "Флаги"; width: 80; inputMethodHints: Qt.ImhDigitsOnly }
                        Button {
                            text: "Создать"
                            onClicked: {
                                var flags = parseInt(chargeFlagsField.text, 10)
                                httpRequest("POST", "/hr/charges", {
                                    sciName: chargeNameField.text,
                                    sciCode: chargeCodeField.text,
                                    sciFlags: isNaN(flags) ? 0 : flags
                                }, function() {
                                    chargeNameField.text = ""
                                    chargeCodeField.text = ""
                                    chargeFlagsField.text = ""
                                    loadSalaryCharges()
                                }, function(status, err) {
                                    console.log("Charge creation failed", status, err)
                                })
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                color: surfaceColor
                radius: 8
                border.color: borderColor
                border.width: 1
                ColumnLayout {
                    anchors.margins: 12
                    spacing: 8
                    RowLayout {
                        spacing: 8
                        Text {
                            text: "Сводка зарплат по периоду"
                            font.pixelSize: 18
                            font.bold: true
                        }
                        Button { text: "Обновить"; onClicked: loadPayrollSummary() }
                    }
                    RowLayout {
                        spacing: 8
                        TextField { text: payrollSummaryFrom; onTextChanged: payrollSummaryFrom = text; placeholderText: "С"; width: 120 }
                        TextField { text: payrollSummaryTo; onTextChanged: payrollSummaryTo = text; placeholderText: "По"; width: 120 }
                    }
                    TableView {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 220
                        model: payrollSummaryModel
                        clip: true
                        TableViewColumn { role: "employeeId"; title: "ID"; width: 60 }
                        TableViewColumn { role: "name"; title: "Сотрудник"; width: 220 }
                        TableViewColumn { role: "position"; title: "Должность"; width: 200 }
                        TableViewColumn { role: "total"; title: "Сумма"; width: 120 }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                color: surfaceColor
                radius: 8
                border.color: borderColor
                border.width: 1
                ColumnLayout {
                    anchors.margins: 12
                    spacing: 8
                    RowLayout {
                        spacing: 8
                        Text {
                            text: "Снимки зарплатных отчётов"
                            font.pixelSize: 18
                            font.bold: true
                        }
                        Button { text: "Обновить"; onClicked: loadPayrollSnapshots() }
                        Button { text: "Сделать снимок"; onClicked: triggerPayrollSnapshot() }
                    }
                    RowLayout {
                        spacing: 8
                        TextField { text: payrollSnapshotFrom; onTextChanged: payrollSnapshotFrom = text; placeholderText: "С"; width: 120 }
                        TextField { text: payrollSnapshotTo; onTextChanged: payrollSnapshotTo = text; placeholderText: "По"; width: 120 }
                    }
                    TableView {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 220
                        model: payrollSnapshotModel
                        clip: true
                        TableViewColumn { role: "id"; title: "ID"; width: 70 }
                        TableViewColumn { role: "period"; title: "Период"; width: 220 }
                        TableViewColumn { role: "created"; title: "Дата"; width: 180 }
                        TableViewColumn { role: "count"; title: "Записей"; width: 100 }
                        TableViewColumn { role: "details"; title: "Пример"; width: 260 }
                    }
                }
            }
        }
    }
}

Component {
    id: productionPage

    ScrollView {
        anchors.fill: parent
        ColumnLayout {
            width: parent.width
            spacing: 16

            RowLayout {
                spacing: 8
                Text {
                    text: "Производственные технологии"
                    font.pixelSize: 22
                    font.bold: true
                }
                Button {
                    text: "Назад"
                    onClicked: contentStack.pop()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                color: surfaceColor
                radius: 8
                border.color: borderColor
                border.width: 1

                ColumnLayout {
                    anchors.margins: 12
                    spacing: 12

                    RowLayout {
                        spacing: 8
                        Button {
                            text: "Обновить технологии"
                            onClicked: loadTechList()
                        }
                    }

                    TableView {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 240
                        model: techModel
                        clip: true
                        TableViewColumn { role: "name"; title: "Название" ; width: 220 }
                        TableViewColumn { role: "goodsId"; title: "Товар"; width: 120 }
                        TableViewColumn { role: "kind"; title: "Тип"; width: 120 }
                        TableViewColumn { role: "version"; title: "Версия"; width: 80 }
                        TableViewColumn { role: "flags"; title: "Флаги"; width: 80 }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                color: surfaceColor
                radius: 8
                border.color: borderColor
                border.width: 1

                ColumnLayout {
                    anchors.margins: 12
                    spacing: 12

                    RowLayout {
                        spacing: 8
                        Text {
                            text: "Ресурсы"
                            font.pixelSize: 18
                            font.bold: true
                        }
                        Button {
                            text: "Обновить ресурсы"
                            onClicked: loadResourceList()
                        }
                    }

                    TableView {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 220
                        model: resourceModel
                        clip: true
                        TableViewColumn { role: "code"; title: "Код"; width: 120 }
                        TableViewColumn { role: "name"; title: "Имя"; width: 200 }
                        TableViewColumn { role: "kind"; title: "Тип"; width: 120 }
                        TableViewColumn { role: "capacity"; title: "Производительность"; width: 160 }
                        TableViewColumn { role: "cost"; title: "Стоимость в час"; width: 150 }
                        TableViewColumn { role: "hours"; title: "Доступные ч"; width: 120 }
                    }
                }
            }
        }
    }
}

Component {
    id: reportsPage

    ScrollView {
        anchors.fill: parent
        ColumnLayout {
            width: parent.width
            spacing: 16

            RowLayout {
                spacing: 8
                Text {
                    text: "Отчёты"
                    font.pixelSize: 22
                    font.bold: true
                }
                Button {
                    text: "Назад"
                    onClicked: contentStack.pop()
                }
            }

            RowLayout {
                spacing: 12
                Layout.fillWidth: true

                Rectangle {
                    Layout.fillWidth: true
                    height: 120
                    color: surfaceColor
                    radius: 8
                    border.color: borderColor

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16

                        Text {
                            text: "📊"
                            font.pixelSize: 32
                        }

                        Text {
                            text: "Продажи"
                            font.bold: true
                        }

                        Text {
                            text: "Анализ продаж за период"
                            font.pixelSize: 12
                            color: secondaryTextColor
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: console.log("Open sales report")
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 120
                    color: surfaceColor
                    radius: 8
                    border.color: borderColor

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16

                        Text {
                            text: "💰"
                            font.pixelSize: 32
                        }

                        Text {
                            text: "Прибыльность"
                            font.bold: true
                        }

                        Text {
                            text: "Рентабельность по товарам"
                            font.pixelSize: 12
                            color: secondaryTextColor
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: console.log("Open profitability report")
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 120
                    color: surfaceColor
                    radius: 8
                    border.color: borderColor

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16

                        Text {
                            text: "📦"
                            font.pixelSize: 32
                        }

                        Text {
                            text: "Остатки"
                            font.bold: true
                        }

                        Text {
                            text: "Складские остатки"
                            font.pixelSize: 12
                            color: secondaryTextColor
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: console.log("Open stock report")
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                color: surfaceColor
                radius: 8
                border.color: borderColor

                ColumnLayout {
                    anchors.margins: 16

                    Text {
                        text: "История отчётов"
                        font.bold: true
                        font.pixelSize: 16
                    }

                    TableView {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 200

                        TableViewColumn { title: "Дата"; width: 180 }
                        TableViewColumn { title: "Отчёт"; width: 200 }
                        TableViewColumn { title: "Период"; width: 150 }
                        TableViewColumn { title: "Статус"; width: 100 }
                    }
                }
            }
        }
    }
}

Component {
    id: settingsPage

    ScrollView {
        anchors.fill: parent
        ColumnLayout {
            width: parent.width
            spacing: 16

            RowLayout {
                spacing: 8
                Text {
                    text: "Настройки"
                    font.pixelSize: 22
                    font.bold: true
                }
                Button {
                    text: "Назад"
                    onClicked: contentStack.pop()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                color: surfaceColor
                radius: 8
                border.color: borderColor

                ColumnLayout {
                    anchors.margins: 16
                    spacing: 12

                    Text {
                        text: "Организация"
                        font.bold: true
                        font.pixelSize: 16
                    }

                    TextField {
                        placeholderText: "Название организации"
                        text: "ООО ТехноСтрой"
                    }

                    TextField {
                        placeholderText: "ИНН"
                        text: "7701234567890"
                    }

                    TextField {
                        placeholderText: "КПП"
                        text: "770101001"
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                color: surfaceColor
                radius: 8
                border.color: borderColor

                ColumnLayout {
                    anchors.margins: 16
                    spacing: 12

                    Text {
                        text: "Система"
                        font.bold: true
                        font.pixelSize: 16
                    }

                    RowLayout {
                        spacing: 8

                        Text { text: "Валюта:" }
                        ComboBox {
                            width: 150
                            model: ["RUB", "USD", "EUR"]
                        }
                    }

                    RowLayout {
                        spacing: 8

                        Text { text: "НДС:" }
                        ComboBox {
                            width: 150
                            model: ["20%", "18%", "10%", "Без НДС"]
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                color: surfaceColor
                radius: 8
                border.color: borderColor

                ColumnLayout {
                    anchors.margins: 16
                    spacing: 12

                    Text {
                        text: "Подключения"
                        font.bold: true
                        font.pixelSize: 16
                    }

                    RowLayout {
                        spacing: 8

                        Text { text: "PostgreSQL:" }
                        Text {
                            text: "localhost:5432"
                            color: "#4CAF50"
                        }
                    }

                    RowLayout {
                        spacing: 8

                        Text { text: "API Server:" }
                        Text {
                            text: "localhost:8080"
                            color: "#4CAF50"
                        }
                    }
                }
            }

            Button {
                text: "Сохранить настройки"
                onClicked: console.log("Settings saved")
            }
        }
    }
}
