# Wi-Fi Direct (Automatic) Implementation

This project implements an automatic Wi-Fi Direct transport on Android and wires it into Flutter via a MethodChannel/EventChannel pair. The behavior is entirely in-app and starts automatically at app launch to sync all data in the background.

**Where to look**
- Flutter integration and lifecycle: `lib/ui/widgets/wifi_direct_sync_watcher.dart`
- Flutter Wi-Fi Direct sync logic: `lib/services/wifi_direct_sync_service.dart`
- Hotspot/LAN TCP sync logic: `lib/services/lan_sync_service.dart`
- LAN manager UI: `lib/ui/pages/lan/lan_manager_page.dart`
- Android Wi-Fi Direct implementation: `android/app/src/main/kotlin/com/example/alex/MainActivity.kt`
- Android permissions/feature declarations: `android/app/src/main/AndroidManifest.xml`

**High-level flow**
1. Flutter starts `WifiDirectSyncWatcher`, which kicks off `WifiDirectSyncService.start()`.
2. The watcher also queues an initial sync request; once a peer is connected, the full dataset is sent automatically.
3. Android sets up `WifiP2pManager`, registers a broadcast receiver, optionally creates a group, and starts peer discovery.
4. As peers are discovered, Android auto-connects to the first discovered peer when not in host-preferred mode.
5. Once a group is formed, the group owner runs a TCP server and clients connect to the owner over a fixed port.
6. Every connection exchanges a hello message and then relays payloads to Flutter. If the device is the group owner, it forwards payloads to all other peers.
7. On `peer_connected` or a local data change trigger, Flutter exports all sync data and broadcasts it. On `message`, Flutter imports data using the merge strategy.

**Flutter-side wiring**
- Control channel: `MethodChannel('wifi_direct')` in `lib/services/wifi_direct_sync_service.dart`.
- Events channel: `EventChannel('wifi_direct_events')` streams status, peer, log, and message events to Flutter.
- `start()` sends `deviceId`, `deviceName`, and `host` (host preference toggle).
- Incoming `message` events trigger automatic import via `SyncService`.
- On `peer_connected` or `triggerSync()`, the full sync payload is exported and sent over Wi-Fi Direct automatically (debounced and rate-limited).
- The LAN Manager UI (`/lan`) uses the same service to expose start/stop, discovery, connect, and disconnect actions.

**Android-side automatic behavior**
- `startWifiDirect(host, id, name)` initializes `WifiP2pManager` and registers the receiver.
- If `hostPreferred == true`, Android calls `createGroup()` to try to become the group owner.
- `discoverPeers()` starts Wi-Fi Direct discovery immediately.
- On peer list updates in `requestPeers()`, if not host-preferred and there are no active connections and not already connecting, the first discovered peer is selected and `connectToPeer()` is called automatically.

**Connection establishment**
- On `WIFI_P2P_CONNECTION_CHANGED_ACTION`, Android requests connection info.
- If the device is group owner, `startServer()` opens a TCP `ServerSocket` on port `42113` and accepts inbound sockets.
- If the device is not group owner, `connectToGroupOwner()` opens a TCP socket to the owner on port `42113`.
- Connection timeout is `3500ms`.

**Peer protocol**
- Each TCP connection sends a JSON hello message: `{ "type": "hello", "id": deviceId, "name": deviceName }`.
- After hello, every line is treated as a payload string.
- If the device is group owner, it forwards payloads to all other peers.
- Flutter is notified for every payload with `type: message`, `payload`, `fromId`, `fromName`.

**Permissions and feature flags**
- `android.permission.ACCESS_WIFI_STATE`
- `android.permission.CHANGE_WIFI_STATE`
- `android.permission.NEARBY_WIFI_DEVICES` (with `neverForLocation`)
- `android.permission.ACCESS_FINE_LOCATION`
- `android.permission.INTERNET`
- `android.permission.ACCESS_NETWORK_STATE`
- `android.hardware.wifi.direct` (optional, `required="false"`)
- Runtime request logic in `lib/services/wifi_direct_sync_service.dart` uses `Permission.nearbyWifiDevices` on SDK 33+ and `Permission.location` on older Android versions.

**Automatic reconnection notes**
- The auto-join logic triggers inside `requestPeers()` after a peer list change.
- After a disconnect, reconnection depends on new peer discovery events firing again.
- Only the first discovered peer is auto-connected in client mode; there is no round-robin or multi-peer connect attempt.

**Testing and operational tips**
- Wi-Fi Direct requires physical Android devices; emulators do not support it.
- To force a group owner, pass `hostPreferred: true` to `WifiDirectSyncWatcher`.
- Mobile hotspot disables Wi-Fi Direct on most Android devices. Use Hotspot/LAN TCP sync when one device is hosting a hotspot.

**Hotspot / LAN (TCP) Sync**
- Works when devices are on the same Wi-Fi network or when one device is hosting a mobile hotspot.
- Start **Start Host** on the host device and share its IP (shown in LAN Manager).
- On the client device, enter the host IP and tap **Connect**.
- Sync uses the same payload as Wi-Fi Direct and merges automatically.

**Key constants**
- Wi-Fi Direct port: `42113` (`WIFI_DIRECT_PORT` in `MainActivity.kt`).
- Hotspot/LAN TCP port: `42114` (`LanSyncService.defaultPort`).
- Connect timeout: `3500ms` (`CONNECT_TIMEOUT_MS` in `MainActivity.kt`).
- Channels: `wifi_direct` (Method), `wifi_direct_events` (Events).
