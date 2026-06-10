import QtQuick 2.15

QtObject {
    id: restClient

    property string apiBaseUrl: "http://localhost:8080/api/v1"
    property string jwtToken: ""
    property bool loading: false
    property string lastError: ""

    signal loadingChanged(bool isLoading)
    signal errorOccurred(string message)
    signal personsLoaded(var data)
    signal goodsLoaded(var data)
    signal billsLoaded(var data)
    signal stockLoaded(var data)
    signal accountsLoaded(var data)
    signal employeesLoaded(var data)

    function setToken(token) {
        jwtToken = token
    }

    function clearToken() {
        jwtToken = ""
    }

    function request(method, path, payload, onSuccess, onError) {
        loading = true
        loadingChanged(true)

        var xhr = new XMLHttpRequest()
        xhr.open(method, apiBaseUrl + path)
        xhr.setRequestHeader("Content-Type", "application/json")
        if (jwtToken.length > 0) {
            xhr.setRequestHeader("Authorization", "Bearer " + jwtToken)
        }
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                loading = false
                loadingChanged(false)

                if (xhr.status === 401 && jwtToken.length > 0) {
                    lastError = "Session expired"
                    errorOccurred("Session expired — please re-login")
                    clearToken()
                    if (onError) onError(xhr.status, {message: "Unauthorized"})
                    return
                }

                if (xhr.status >= 200 && xhr.status < 300) {
                    try {
                        var parsed = JSON.parse(xhr.responseText)
                        if (onSuccess) onSuccess(parsed)
                    } catch (e) {
                        lastError = "Invalid response"
                        errorOccurred("Failed to parse response")
                        if (onError) onError(0, {message: "Parse error"})
                    }
                } else {
                    lastError = xhr.statusText
                    errorOccurred("HTTP " + xhr.status + ": " + xhr.statusText)
                    if (onError) onError(xhr.status, xhr.responseText)
                }
            }
        }
        xhr.send(payload ? JSON.stringify(payload) : null)
    }

    function get(path, onSuccess, onError) {
        request("GET", path, null, onSuccess, onError)
    }

    function post(path, data, onSuccess, onError) {
        request("POST", path, data, onSuccess, onError)
    }

    function put(path, data, onSuccess, onError) {
        request("PUT", path, data, onSuccess, onError)
    }

    function del(path, onSuccess, onError) {
        request("DELETE", path, null, onSuccess, onError)
    }

    function loadPersons(page, pageSize, filters) {
        var path = "/persons"
        if (page !== undefined) path += "?page=" + page + "&pageSize=" + (pageSize || 50)
        get(path, function(resp) { personsLoaded(resp) }, function(status, err) { errorOccurred("Failed to load persons") })
    }

    function loadGoods(page, pageSize) {
        var path = "/goods"
        if (page !== undefined) path += "?page=" + page + "&pageSize=" + (pageSize || 50)
        get(path, function(resp) { goodsLoaded(resp) }, function(status, err) { errorOccurred("Failed to load goods") })
    }

    function loadBills(page, pageSize) {
        var path = "/bills"
        if (page !== undefined) path += "?page=" + page + "&pageSize=" + (pageSize || 50)
        get(path, function(resp) { billsLoaded(resp) }, function(status, err) { errorOccurred("Failed to load bills") })
    }

    function loadStock(locationId) {
        var path = "/stock"
        if (locationId !== undefined) path += "?locationId=" + locationId
        get(path, function(resp) { stockLoaded(resp) }, function(status, err) { errorOccurred("Failed to load stock") })
    }

    function loadAccounts() {
        get("/accounts", function(resp) { accountsLoaded(resp) }, function(status, err) { errorOccurred("Failed to load accounts") })
    }

    function loadEmployees() {
        get("/employees", function(resp) { employeesLoaded(resp) }, function(status, err) { errorOccurred("Failed to load employees") })
    }

    function createPerson(data, onSuccess) { post("/persons", data, onSuccess, function(s, e) { errorOccurred("Failed to create person") }) }
    function updatePerson(id, data, onSuccess) { put("/persons/" + id, data, onSuccess, function(s,e) { errorOccurred("Failed to update person") }) }
    function deletePerson(id, onSuccess) { del("/persons/" + id, onSuccess, function(s,e) { errorOccurred("Failed to delete person") }) }

    function createGoods(data, onSuccess) { post("/goods", data, onSuccess, function(s,e) { errorOccurred("Failed to create goods") }) }
    function updateGoods(id, data, onSuccess) { put("/goods/" + id, data, onSuccess, function(s,e) { errorOccurred("Failed to update goods") }) }
    function deleteGoods(id, onSuccess) { del("/goods/" + id, onSuccess, function(s,e) { errorOccurred("Failed to delete goods") }) }

    function createBill(data, onSuccess) { post("/bills", data, onSuccess, function(s,e) { errorOccurred("Failed to create bill") }) }
    function postBill(id, onSuccess) { post("/bills/" + id + "/post", {}, onSuccess, function(s,e) { errorOccurred("Failed to post bill") }) }
}
