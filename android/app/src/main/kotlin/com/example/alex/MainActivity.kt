package com.example.alex

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.NetworkInfo
import android.net.wifi.WpsInfo
import android.net.wifi.p2p.WifiP2pConfig
import android.net.wifi.p2p.WifiP2pDevice
import android.net.wifi.p2p.WifiP2pDeviceList
import android.net.wifi.p2p.WifiP2pInfo
import android.net.wifi.p2p.WifiP2pManager
import android.os.SystemClock
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedReader
import java.io.BufferedWriter
import java.io.InputStreamReader
import java.io.OutputStreamWriter
import java.io.PrintWriter
import java.net.InetSocketAddress
import java.net.ServerSocket
import java.net.Socket
import java.util.Collections
import java.util.concurrent.Executors
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private val timeGuardChannelName = "alex/time_guard"
    private val wifiMethodChannelName = "wifi_direct"
    private val wifiEventChannelName = "wifi_direct_events"
    private val wifiPort = 42113
    private val connectTimeoutMs = 3500

    private var wifiManager: WifiP2pManager? = null
    private var wifiChannel: WifiP2pManager.Channel? = null
    private var receiver: BroadcastReceiver? = null
    private var receiverRegistered = false
    private var eventSink: EventChannel.EventSink? = null

    private val executor = Executors.newCachedThreadPool()
    private var serverSocket: ServerSocket? = null
    private var serverRunning = false
    private var clientConnection: PeerConnection? = null
    private val peerConnections = Collections.synchronizedList(mutableListOf<PeerConnection>())

    private var hostPreferred = false
    private var deviceId = "unknown"
    private var deviceName = "Android"
    private var connecting = false
    private var isConnected = false
    private var isGroupOwner = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, timeGuardChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "elapsedRealtime" -> result.success(SystemClock.elapsedRealtime())
                    "openDateTimeSettings" -> {
                        startActivity(Intent(Settings.ACTION_DATE_SETTINGS))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, wifiMethodChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startWifiDirect" -> {
                        val args = call.arguments as? Map<*, *>
                        hostPreferred = args?.get("host") as? Boolean ?: false
                        deviceId = args?.get("deviceId") as? String ?: "unknown"
                        deviceName = args?.get("deviceName") as? String ?: "Android"
                        startWifiDirect()
                        result.success(null)
                    }
                    "sendMessage" -> {
                        val args = call.arguments as? Map<*, *>
                        val payload = args?.get("payload") as? String
                        if (payload.isNullOrBlank()) {
                            result.error("missing_payload", "Payload is required", null)
                        } else {
                            sendPayload(payload)
                            result.success(null)
                        }
                    }
                    "stopWifiDirect" -> {
                        stopWifiDirect()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, wifiEventChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })
    }

    override fun onDestroy() {
        stopWifiDirect()
        super.onDestroy()
    }

    private fun startWifiDirect() {
        if (wifiManager == null) {
            wifiManager = getSystemService(Context.WIFI_P2P_SERVICE) as WifiP2pManager
        }
        if (wifiChannel == null) {
            wifiChannel = wifiManager?.initialize(this, mainLooper, null)
        }
        if (receiver == null) {
            receiver = WifiDirectReceiver()
        }
        if (!receiverRegistered) {
            val filter = IntentFilter().apply {
                addAction(WifiP2pManager.WIFI_P2P_STATE_CHANGED_ACTION)
                addAction(WifiP2pManager.WIFI_P2P_PEERS_CHANGED_ACTION)
                addAction(WifiP2pManager.WIFI_P2P_CONNECTION_CHANGED_ACTION)
                addAction(WifiP2pManager.WIFI_P2P_THIS_DEVICE_CHANGED_ACTION)
            }
            registerReceiver(receiver, filter)
            receiverRegistered = true
        }

        if (hostPreferred) {
            createGroup()
        }

        discoverPeers()
        sendStatus("started")
    }

    private fun stopWifiDirect() {
        if (receiverRegistered) {
            try {
                unregisterReceiver(receiver)
            } catch (_: Exception) {
            }
            receiverRegistered = false
        }
        receiver = null
        try {
            wifiManager?.stopPeerDiscovery(wifiChannel, null)
        } catch (_: Exception) {
        }
        try {
            wifiManager?.removeGroup(wifiChannel, null)
        } catch (_: Exception) {
        }
        closeAllConnections()
        sendStatus("stopped")
    }

    private fun discoverPeers() {
        wifiManager?.discoverPeers(wifiChannel, object : WifiP2pManager.ActionListener {
            override fun onSuccess() {
                sendStatus("discovering")
            }

            override fun onFailure(reason: Int) {
                sendStatus("discover_failed", mapOf("reason" to reason))
            }
        })
    }

    private fun createGroup() {
        wifiManager?.createGroup(wifiChannel, object : WifiP2pManager.ActionListener {
            override fun onSuccess() {
                sendStatus("group_created")
            }

            override fun onFailure(reason: Int) {
                sendStatus("group_create_failed", mapOf("reason" to reason))
            }
        })
    }

    private fun connectToPeer(device: WifiP2pDevice) {
        val config = WifiP2pConfig().apply {
            deviceAddress = device.deviceAddress
            wps.setup = WpsInfo.PBC
            groupOwnerIntent = if (hostPreferred) 15 else 0
        }
        connecting = true
        wifiManager?.connect(wifiChannel, config, object : WifiP2pManager.ActionListener {
            override fun onSuccess() {
                sendStatus("connecting")
            }

            override fun onFailure(reason: Int) {
                connecting = false
                sendStatus("connect_failed", mapOf("reason" to reason))
            }
        })
    }

    private fun startServer() {
        if (serverRunning) {
            return
        }
        serverRunning = true
        executor.execute {
            try {
                serverSocket = ServerSocket(wifiPort)
                sendStatus("server_listening")
                while (serverRunning) {
                    val socket = serverSocket?.accept() ?: break
                    socket.tcpNoDelay = true
                    handleSocket(socket, isClient = false)
                }
            } catch (e: Exception) {
                sendLog("Server error: ${e.message}")
            } finally {
                serverRunning = false
                try {
                    serverSocket?.close()
                } catch (_: Exception) {
                }
                serverSocket = null
            }
        }
    }

    private fun connectToGroupOwner(info: WifiP2pInfo) {
        val address = info.groupOwnerAddress ?: return
        executor.execute {
            try {
                if (clientConnection?.socket?.isConnected == true) {
                    return@execute
                }
                val socket = Socket()
                socket.tcpNoDelay = true
                socket.connect(
                    InetSocketAddress(address.hostAddress, wifiPort),
                    connectTimeoutMs
                )
                handleSocket(socket, isClient = true)
                sendStatus("client_connected")
            } catch (e: Exception) {
                sendStatus("client_connect_failed", mapOf("error" to (e.message ?: "error")))
            }
        }
    }

    private fun handleSocket(socket: Socket, isClient: Boolean) {
        val reader = BufferedReader(InputStreamReader(socket.getInputStream()))
        val writer = PrintWriter(BufferedWriter(OutputStreamWriter(socket.getOutputStream())), true)
        val connection = PeerConnection(socket, reader, writer)
        if (isClient) {
            clientConnection = connection
        } else {
            peerConnections.add(connection)
        }

        executor.execute {
            sendHello(connection)
            try {
                while (true) {
                    val line = connection.reader.readLine() ?: break
                    if (line.isBlank()) continue
                    val payload = line.trim()
                    if (handleHello(connection, payload)) {
                        continue
                    }
                    sendMessageEvent(payload, connection.peerId, connection.peerName)
                    if (isGroupOwner) {
                        forwardToPeers(payload, connection)
                    }
                }
            } catch (e: Exception) {
                sendLog("Socket error: ${e.message}")
            } finally {
                closeConnection(connection, isClient)
            }
        }
    }

    private fun sendHello(connection: PeerConnection) {
        val hello = JSONObject()
        hello.put("type", "hello")
        hello.put("id", deviceId)
        hello.put("name", deviceName)
        sendToConnection(connection, hello.toString())
    }

    private fun handleHello(connection: PeerConnection, payload: String): Boolean {
        return try {
            val json = JSONObject(payload)
            if (json.optString("type") == "hello") {
                connection.peerId = json.optString("id", null)
                connection.peerName = json.optString("name", null)
                sendEvent(
                    "peer_connected",
                    mapOf(
                        "peerId" to connection.peerId,
                        "peerName" to connection.peerName
                    )
                )
                true
            } else {
                false
            }
        } catch (_: Exception) {
            false
        }
    }

    private fun forwardToPeers(payload: String, sender: PeerConnection) {
        val snapshot = synchronized(peerConnections) { peerConnections.toList() }
        for (peer in snapshot) {
            if (peer === sender) continue
            sendToConnection(peer, payload)
        }
    }

    private fun sendPayload(payload: String) {
        executor.execute {
            if (isGroupOwner) {
                val snapshot = synchronized(peerConnections) { peerConnections.toList() }
                for (peer in snapshot) {
                    sendToConnection(peer, payload)
                }
            } else {
                val connection = clientConnection
                if (connection != null) {
                    sendToConnection(connection, payload)
                }
            }
        }
    }

    private fun sendToConnection(connection: PeerConnection, payload: String) {
        synchronized(connection) {
            try {
                connection.writer.println(payload)
                connection.writer.flush()
            } catch (e: Exception) {
                sendLog("Send failed: ${e.message}")
            }
        }
    }

    private fun sendMessageEvent(payload: String, fromId: String?, fromName: String?) {
        sendEvent(
            "message",
            mapOf(
                "payload" to payload,
                "fromId" to fromId,
                "fromName" to fromName
            )
        )
    }

    private fun closeAllConnections() {
        val snapshot = synchronized(peerConnections) { peerConnections.toList() }
        for (peer in snapshot) {
            closeConnection(peer, false)
        }
        peerConnections.clear()
        clientConnection?.let { closeConnection(it, true) }
        clientConnection = null
    }

    private fun closeConnection(connection: PeerConnection, isClient: Boolean) {
        try {
            connection.reader.close()
        } catch (_: Exception) {
        }
        try {
            connection.writer.close()
        } catch (_: Exception) {
        }
        try {
            connection.socket.close()
        } catch (_: Exception) {
        }
        if (isClient) {
            if (clientConnection === connection) {
                clientConnection = null
            }
        } else {
            peerConnections.remove(connection)
        }
    }

    private fun sendStatus(status: String, extras: Map<String, Any?> = emptyMap()) {
        sendEvent("status", mapOf("status" to status) + extras)
    }

    private fun sendLog(message: String) {
        sendEvent("log", mapOf("message" to message))
    }

    private fun sendEvent(type: String, data: Map<String, Any?>) {
        val payload = HashMap<String, Any?>()
        payload["type"] = type
        payload.putAll(data)
        runOnUiThread {
            eventSink?.success(payload)
        }
    }

    private inner class WifiDirectReceiver : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                WifiP2pManager.WIFI_P2P_STATE_CHANGED_ACTION -> {
                    val state = intent.getIntExtra(
                        WifiP2pManager.EXTRA_WIFI_STATE,
                        WifiP2pManager.WIFI_P2P_STATE_DISABLED
                    )
                    if (state == WifiP2pManager.WIFI_P2P_STATE_ENABLED) {
                        sendStatus("p2p_enabled")
                    } else {
                        sendStatus("p2p_disabled")
                    }
                }
                WifiP2pManager.WIFI_P2P_PEERS_CHANGED_ACTION -> {
                    requestPeers()
                }
                WifiP2pManager.WIFI_P2P_CONNECTION_CHANGED_ACTION -> {
                    val networkInfo = intent.getParcelableExtra<NetworkInfo>(
                        WifiP2pManager.EXTRA_NETWORK_INFO
                    )
                    if (networkInfo?.isConnected == true) {
                        wifiManager?.requestConnectionInfo(
                            wifiChannel,
                            WifiP2pManager.ConnectionInfoListener { info ->
                                handleConnectionInfo(info)
                            }
                        )
                    } else {
                        isConnected = false
                        isGroupOwner = false
                        connecting = false
                        closeAllConnections()
                        sendStatus("disconnected")
                        if (!hostPreferred) {
                            discoverPeers()
                        }
                    }
                }
                WifiP2pManager.WIFI_P2P_THIS_DEVICE_CHANGED_ACTION -> {
                    // Ignored for now
                }
            }
        }
    }

    private fun requestPeers() {
        wifiManager?.requestPeers(wifiChannel) { peers: WifiP2pDeviceList? ->
            val list = peers?.deviceList?.toList() ?: emptyList()
            sendStatus("peers", mapOf("count" to list.size))
            if (!hostPreferred && !isConnected && !connecting && list.isNotEmpty()) {
                connectToPeer(list.first())
            }
        }
    }

    private fun handleConnectionInfo(info: WifiP2pInfo) {
        if (!info.groupFormed) {
            return
        }
        isConnected = true
        isGroupOwner = info.isGroupOwner
        connecting = false
        sendStatus("connected", mapOf("groupOwner" to info.isGroupOwner))
        if (info.isGroupOwner) {
            startServer()
        } else {
            connectToGroupOwner(info)
        }
    }

    private class PeerConnection(
        val socket: Socket,
        val reader: BufferedReader,
        val writer: PrintWriter
    ) {
        @Volatile
        var peerId: String? = null

        @Volatile
        var peerName: String? = null
    }
}
