import QtQuick 2.15

QtObject {
    id: wsClient

    property var webSocket: null
    property string url: "ws://localhost:8080"
    property bool connected: false

    function connect() {
        webSocket = new WebSocket(url);
        webSocket.onopen = function() {
            console.log("WebSocket connected");
            connected = true;
        };
        webSocket.onclose = function() {
            console.log("WebSocket disconnected");
            connected = false;
            // Attempt to reconnect after 3 seconds
            setTimeout(connect, 3000);
        };
        webSocket.onerror = function(error) {
            console.log("WebSocket error:", error);
        };
        webSocket.onmessage = function(event) {
            console.log("WebSocket message received:", event.data);
            // Handle message by type (to be implemented)
            var message = JSON.parse(event.data);
            handleMessage(message);
        };
    }

    function disconnect() {
        if (webSocket) {
            webSocket.close();
        }
    }

    function sendMessage(message) {
        if (webSocket && webSocket.readyState === WebSocket.OPEN) {
            webSocket.send(JSON.stringify(message));
        }
    }

    function handleMessage(message) {
        // Stub for handling messages by type
        switch (message.type) {
            // Cases will be implemented later
            default:
                console.log("Unhandled message type:", message.type);
        }
    }

    // Auto-connect on component completion
    Component.onCompleted: connect()
}