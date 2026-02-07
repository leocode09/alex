import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../../services/wifi_direct_sync_service.dart';
import '../../../services/lan_sync_service.dart';

class LanManagerPage extends StatefulWidget {
  const LanManagerPage({super.key});

  @override
  State<LanManagerPage> createState() => _LanManagerPageState();
}

class _LanManagerPageState extends State<LanManagerPage> {
  final WifiDirectSyncService _wifiService = WifiDirectSyncService();
  final LanSyncService _lanService = LanSyncService();
  final TextEditingController _hostController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _wifiService.start();
    _lanService.refreshLocalAddresses();
  }

  @override
  void dispose() {
    _hostController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_wifiService, _lanService]),
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('LAN Manager',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildGroupTitle('Wi-Fi Direct'),
              _buildWifiStatusCard(context),
              _buildWifiPreferencesCard(context),
              _buildWifiControlsCard(context),
              _buildWifiPeersCard(context),
              _buildWifiConnectedCard(context),
              _buildWifiLogsCard(context),
              const SizedBox(height: 8),
              _buildGroupTitle('Hotspot / LAN (TCP)'),
              _buildLanStatusCard(context),
              _buildLanAddressesCard(context),
              _buildLanControlsCard(context),
              _buildLanClientsCard(context),
              _buildLanLogsCard(context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGroupTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildWifiStatusCard(BuildContext context) {
    final status = _formatStatus(_wifiService.status);
    final connection =
        _wifiService.isConnected ? 'Connected' : 'Not connected';
    final role = _wifiService.isConnected
        ? (_wifiService.isGroupOwner ? 'Group owner' : 'Client')
        : 'N/A';
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Status'),
          const SizedBox(height: 8),
          Text('State: $status'),
          Text('Connection: $connection'),
          Text('Role: $role'),
          if (_wifiService.lastError != null) ...[
            const SizedBox(height: 8),
            Text(
              _wifiService.lastError!,
              style: const TextStyle(color: Colors.red),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWifiPreferencesCard(BuildContext context) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Preferences'),
          SwitchListTile(
            title: const Text('Host Preferred'),
            subtitle:
                const Text('Try to become group owner when starting'),
            value: _wifiService.hostPreferred,
            onChanged: (value) => _wifiService.setHostPreferred(value),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildWifiControlsCard(BuildContext context) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Controls'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: _wifiService.isRunning
                    ? null
                    : () => _wifiService.start(
                          hostPreferred: _wifiService.hostPreferred,
                        ),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start'),
              ),
              OutlinedButton.icon(
                onPressed: _wifiService.isRunning
                    ? () => _wifiService.discoverPeers()
                    : null,
                icon: const Icon(Icons.search),
                label: const Text('Discover'),
              ),
              OutlinedButton.icon(
                onPressed:
                    _wifiService.isConnected ? _wifiService.disconnect : null,
                icon: const Icon(Icons.link_off),
                label: const Text('Disconnect'),
              ),
              OutlinedButton.icon(
                onPressed: _wifiService.isRunning ? _wifiService.stop : null,
                icon: const Icon(Icons.stop),
                label: const Text('Stop'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWifiPeersCard(BuildContext context) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Discovered Peers'),
          const SizedBox(height: 8),
          if (_wifiService.peers.isEmpty)
            const Text('No peers discovered yet.')
          else
            ..._wifiService.peers.map((peer) {
              final isConnected = _wifiService.connectedPeers.any(
                (connected) =>
                    (peer.address != null &&
                        connected.address == peer.address) ||
                    (peer.name != null && connected.name == peer.name),
              );
              final subtitle = [
                if (peer.address != null) peer.address!,
                if (peer.status != null) 'Status: ${peer.status}',
              ].join(' • ');
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(peer.displayName),
                subtitle: subtitle.isEmpty ? null : Text(subtitle),
                trailing: isConnected
                    ? const Text('Connected')
                    : TextButton(
                        onPressed: peer.address == null
                            ? null
                            : () => _wifiService.connectToPeer(
                                  peer.address!,
                                ),
                        child: const Text('Connect'),
                      ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildWifiConnectedCard(BuildContext context) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Connected Peers'),
          const SizedBox(height: 8),
          if (_wifiService.connectedPeers.isEmpty)
            const Text('No connected peers.')
          else
            ..._wifiService.connectedPeers.map((peer) {
              final subtitle = peer.id ?? peer.address;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(peer.displayName),
                subtitle: subtitle == null ? null : Text(subtitle),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildWifiLogsCard(BuildContext context) {
    final logs = _wifiService.logs;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Logs'),
          const SizedBox(height: 8),
          if (logs.isEmpty)
            const Text('No logs yet.')
          else
            ...logs.reversed.take(5).map((log) => Text(log)).toList(),
        ],
      ),
    );
  }

  Widget _buildLanStatusCard(BuildContext context) {
    final status = _formatStatus(_lanService.status);
    final server = _lanService.isServerRunning ? 'Running' : 'Stopped';
    final client = _lanService.isClientConnected
        ? 'Connected'
        : (_lanService.isClientConnecting ? 'Connecting' : 'Disconnected');
    final connections = _lanService.connectedClients.length;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('LAN Status'),
          const SizedBox(height: 8),
          Text('State: $status'),
          Text('Server: $server'),
          Text('Client: $client'),
          Text('Clients connected: $connections'),
          if (_lanService.lastError != null) ...[
            const SizedBox(height: 8),
            Text(
              _lanService.lastError!,
              style: const TextStyle(color: Colors.red),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLanAddressesCard(BuildContext context) {
    final addresses = _lanService.localAddresses;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Local IP Addresses'),
          const SizedBox(height: 8),
          if (addresses.isEmpty)
            const Text('No IPs detected yet. Tap refresh.')
          else
            ...addresses.map((ip) => Text('$ip:${LanSyncService.defaultPort}')),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _lanService.refreshLocalAddresses,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh IPs'),
          ),
        ],
      ),
    );
  }

  Widget _buildLanControlsCard(BuildContext context) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Controls'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: _lanService.isServerRunning
                    ? null
                    : () => _lanService.startServer(),
                icon: const Icon(Icons.wifi_tethering),
                label: const Text('Start Host'),
              ),
              OutlinedButton.icon(
                onPressed: _lanService.isServerRunning
                    ? _lanService.stopServer
                    : null,
                icon: const Icon(Icons.stop),
                label: const Text('Stop Host'),
              ),
              OutlinedButton.icon(
                onPressed: _lanService.isConnected
                    ? () => _lanService.triggerSync(reason: 'manual')
                    : null,
                icon: const Icon(Icons.sync),
                label: const Text('Sync Now'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _hostController,
            decoration: const InputDecoration(
              labelText: 'Host IP (e.g. 192.168.43.1)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: _lanService.isClientConnecting
                    ? null
                    : () => _lanService.connectToHost(_hostController.text),
                icon: const Icon(Icons.link),
                label: const Text('Connect'),
              ),
              OutlinedButton.icon(
                onPressed: _lanService.isClientConnected
                    ? _lanService.disconnectClient
                    : null,
                icon: const Icon(Icons.link_off),
                label: const Text('Disconnect'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Both devices must be on the same Wi-Fi or hotspot network.',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildLanClientsCard(BuildContext context) {
    final clients = _lanService.connectedClients;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Connected Clients'),
          const SizedBox(height: 8),
          if (clients.isEmpty)
            const Text('No LAN clients connected.')
          else
            ...clients.map((client) => Text(client)).toList(),
        ],
      ),
    );
  }

  Widget _buildLanLogsCard(BuildContext context) {
    final logs = _lanService.logs;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('LAN Logs'),
          const SizedBox(height: 8),
          if (logs.isEmpty)
            const Text('No logs yet.')
          else
            ...logs.reversed.take(5).map((log) => Text(log)).toList(),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.8,
      ),
    );
  }

  String _formatStatus(String status) {
    if (status.isEmpty) {
      return 'Unknown';
    }
    return status
        .replaceAll('_', ' ')
        .split(' ')
        .map((part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }
}
