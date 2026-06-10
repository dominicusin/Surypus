import QtQuick 2.15

QtObject {
    id: wsClient

    property var webSocket: null
    property string wsUrl: "ws://localhost:8080/api/v1/ws"
    property string authToken: ""
    property bool connected: false
    property int reconnectDelay: 1000
    property int maxReconnectDelay: 30000

    signal connectedChanged(bool isConnected)
    signal messageReceived(string type, var data)
    signal error(string message)

    function connect() {
        if (webSocket && webSocket.readyState === WebSocket.OPEN) return

        var url = wsUrl
        if (authToken.length > 0) url += "?token=" + encodeURIComponent(authToken)

        webSocket = new WebSocket(url)
        webSocket.onopen = function() {
            console.log("WebSocket connected")
            connected = true
            connectedChanged(true)
            reconnectDelay = 1000
        }
        webSocket.onclose = function() {
            console.log("WebSocket disconnected")
            connected = false
            connectedChanged(false)
            scheduleReconnect()
        }
        webSocket.onerror = function(err) {
            console.log("WebSocket error:", err)
            error("WebSocket connection error")
        }
        webSocket.onmessage = function(event) {
            try {
                var msg = JSON.parse(event.data)
                messageReceived(msg.type || "unknown", msg)
            } catch (e) {
                console.log("Failed to parse WebSocket message:", e)
            }
        }
    }

    function scheduleReconnect() {
        if (reconnectDelay < maxReconnectDelay) {
            reconnectDelay = Math.min(reconnectDelay * 2, maxReconnectDelay)
        }
        console.log("Reconnecting in " + reconnectDelay + "ms...")
        setTimeout(function() { connect() }, reconnectDelay)
    }

    function disconnect() {
        if (webSocket) {
            try { webSocket.close() } catch(e) {}
            webSocket = null
        }
        connected = false
        connectedChanged(false)
    }

    function send(type, data) {
        if (webSocket && webSocket.readyState === WebSocket.OPEN) {
            webSocket.send(JSON.stringify({type: type, payload: data}))
        } else {
            error("WebSocket not connected")
        }
    }

    Component.onCompleted: connect()
}
