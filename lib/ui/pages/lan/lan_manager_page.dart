import 'package:flutter/material.dart';

import '../../../services/wifi_direct_sync_service.dart';

class LanManagerPage extends StatefulWidget {
  const LanManagerPage({super.key});

  @override
  State<LanManagerPage> createState() => _LanManagerPageState();
}

class _LanManagerPageState extends State<LanManagerPage> {
  final WifiDirectSyncService _service = WifiDirectSyncService();

  @override
  void initState() {
    super.initState();
    _service.start();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _service,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('LAN Manager',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildStatusCard(context),
              _buildPreferencesCard(context),
              _buildControlsCard(context),
              _buildPeersCard(context),
              _buildConnectedCard(context),
              _buildLogsCard(context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusCard(BuildContext context) {
    final status = _formatStatus(_service.status);
    final connection =
        _service.isConnected ? 'Connected' : 'Not connected';
    final role = _service.isConnected
        ? (_service.isGroupOwner ? 'Group owner' : 'Client')
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
          if (_service.lastError != null) ...[
            const SizedBox(height: 8),
            Text(
              _service.lastError!,
              style: const TextStyle(color: Colors.red),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreferencesCard(BuildContext context) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Preferences'),
          SwitchListTile(
            title: const Text('Host Preferred'),
            subtitle:
                const Text('Try to become group owner when starting'),
            value: _service.hostPreferred,
            onChanged: (value) => _service.setHostPreferred(value),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildControlsCard(BuildContext context) {
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
                onPressed: _service.isRunning
                    ? null
                    : () => _service.start(
                          hostPreferred: _service.hostPreferred,
                        ),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start'),
              ),
              OutlinedButton.icon(
                onPressed: _service.isRunning
                    ? () => _service.discoverPeers()
                    : null,
                icon: const Icon(Icons.search),
                label: const Text('Discover'),
              ),
              OutlinedButton.icon(
                onPressed:
                    _service.isConnected ? _service.disconnect : null,
                icon: const Icon(Icons.link_off),
                label: const Text('Disconnect'),
              ),
              OutlinedButton.icon(
                onPressed: _service.isRunning ? _service.stop : null,
                icon: const Icon(Icons.stop),
                label: const Text('Stop'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPeersCard(BuildContext context) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Discovered Peers'),
          const SizedBox(height: 8),
          if (_service.peers.isEmpty)
            const Text('No peers discovered yet.')
          else
            ..._service.peers.map((peer) {
              final isConnected = _service.connectedPeers.any(
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
                            : () => _service.connectToPeer(
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

  Widget _buildConnectedCard(BuildContext context) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Connected Peers'),
          const SizedBox(height: 8),
          if (_service.connectedPeers.isEmpty)
            const Text('No connected peers.')
          else
            ..._service.connectedPeers.map((peer) {
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

  Widget _buildLogsCard(BuildContext context) {
    final logs = _service.logs;
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
