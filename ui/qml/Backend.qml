pragma Singleton
import QtQuick
import Kplus
import QtWebSockets

// The connection to the C# backend: JSON-RPC requests over a private loopback WebSocket, plus pushed events.
QtObject {
    id: root

    property bool connected: false
    property bool closed: false
    signal eventReceived(string name, var data)

    property var _pending: ({})
    property int _seq: 1
    property var _queue: []

    /** call("library.list", {}, function (result) {...}, function (message) {...}) */
    function call(method, params, ok, fail) {
        var id = _seq++
        _pending[id] = { ok: ok, fail: fail }
        var text = JSON.stringify({ id: id, method: method, params: params || {} })
        if (connected) _ws.sendTextMessage(text)
        else _queue.push(text)
    }

    /** Fire-and-forget (errors are logged only). */
    function send(method, params) { call(method, params, null, function (e) { console.warn(method + " failed: " + e) }) }

    function _dispatch(raw) {
        var msg
        try { msg = JSON.parse(raw) } catch (e) { return }
        if (msg.event) { eventReceived(msg.event, msg.data); return }
        var p = _pending[msg.id]
        if (!p) return
        delete _pending[msg.id]
        if (msg.error !== undefined && msg.error !== null) { if (p.fail) p.fail(String(msg.error)); else console.warn("rpc error: " + msg.error) }
        else if (p.ok) p.ok(msg.result)
    }

    /** Reply to a dialog the backend asked us to show. */
    function reply(payload) { if (connected) _ws.sendTextMessage(JSON.stringify(payload)) }

    property WebSocket _ws: WebSocket {
        url: Launch.ws
        active: Launch.ws !== ""
        onStatusChanged: {
            if (status === WebSocket.Open) {
                root.connected = true
                var q = root._queue
                root._queue = []
                for (var i = 0; i < q.length; i++) sendTextMessage(q[i])
            } else if (status === WebSocket.Closed || status === WebSocket.Error) {
                var was = root.connected
                root.connected = false
                if (was || status === WebSocket.Error) root.closed = true
            }
        }
        onTextMessageReceived: function (message) { root._dispatch(message) }
    }
}
