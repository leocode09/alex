import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/wifi_direct_sync_service.dart';
import '../../../services/lan_sync_service.dart';

enum LanActionTimeRange {
  today,
  thisWeek,
  thisMonth,
  thisYear,
  allTime,
}

class LanManagerPage extends StatefulWidget {
  const LanManagerPage({super.key});

  @override
  State<LanManagerPage> createState() => _LanManagerPageState();
}

class _LanManagerPageState extends State<LanManagerPage> {
  static const String _allDevicesFilter = '__all_devices__';
  final WifiDirectSyncService _service = WifiDirectSyncService();
  final LanSyncService _lanService = LanSyncService();
  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _deviceNameController = TextEditingController();
  String _selectedDeviceFilter = _allDevicesFilter;
  LanActionTimeRange _selectedTimeRange = LanActionTimeRange.today;
  bool _showAdvancedTools = false;

  @override
  void initState() {
    super.initState();
    _lanService.initialize().then((_) {
      if (!mounted) {
        return;
      }
      _deviceNameController.text = _lanService.deviceName;
    });
    _service.start();
    _lanService.start();
    _lanService.refreshLocalAddresses();
  }

  @override
  void dispose() {
    _hostController.dispose();
    _deviceNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_service, _lanService]),
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('LAN Sharing',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildQuickStartCard(context),
              _buildLanStatusCard(context),
              _buildLanControlsCard(context),
              _buildLanPeersCard(context),
              _buildLanClientsCard(context),
              _buildLanDeviceNameCard(context),
              _buildAdvancedToggleCard(context),
              if (_showAdvancedTools) ...[
                _buildGroupTitle('Advanced Tools'),
                _buildLanManualConnectCard(context),
                _buildLanAddressesCard(context),
                _buildLanActionsCard(context),
                const SizedBox(height: 8),
                _buildGroupTitle('Wi-Fi Direct (Advanced)'),
                _buildStatusCard(context),
                _buildPreferencesCard(context),
                _buildControlsCard(context),
                _buildPeersCard(context),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickStartCard(BuildContext context) {
    return _card(
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick setup',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: 8),
          Text('1. Connect both devices to the same Wi-Fi or hotspot.'),
          SizedBox(height: 4),
          Text('2. Tap "Start Sharing" on both devices.'),
          SizedBox(height: 4),
          Text('3. Wait for the device to appear, then sync.'),
        ],
      ),
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

  Widget _buildStatusCard(BuildContext context) {
    final status = _formatStatus(_service.status);
    final connection = _service.isConnected ? 'Connected' : 'Not connected';
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
            subtitle: const Text('Try to become group owner when starting'),
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
                onPressed:
                    _service.isRunning ? () => _service.discoverPeers() : null,
                icon: const Icon(Icons.search),
                label: const Text('Discover'),
              ),
              OutlinedButton.icon(
                onPressed: _service.isConnected ? _service.disconnect : null,
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
              final subtitle = [
                if (peer.address != null) peer.address!,
                if (peer.status != null) 'Status: ${peer.status}',
              ].join(' - ');
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(peer.displayName),
                subtitle: subtitle.isEmpty ? null : Text(subtitle),
                trailing: TextButton(
                  onPressed: peer.address == null
                      ? null
                      : () => _service.connectToPeer(peer.address!),
                  child: const Text('Connect'),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildLanStatusCard(BuildContext context) {
    final status = _formatStatus(_lanService.status);
    final running = _lanService.isRunning ? 'On' : 'Off';
    final connections = _lanService.connectedPeers.length;
    final connectionSummary = connections == 1
        ? '1 device connected'
        : '$connections devices connected';

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Connection Status'),
          const SizedBox(height: 8),
          Text('Sharing: $running'),
          Text('Status: $status'),
          Text(connectionSummary),
          if (_lanService.lastError != null) ...[
            const SizedBox(height: 8),
            Text(
              'Issue: ${_lanService.lastError!}',
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLanDeviceNameCard(BuildContext context) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Your Device Name'),
          const SizedBox(height: 8),
          TextField(
            controller: _deviceNameController,
            decoration: const InputDecoration(
              labelText: 'Device name',
              hintText: 'Example: Counter 1',
              border: OutlineInputBorder(),
              helperText: 'This is what other devices will see.',
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _saveDeviceName(context),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: () => _saveDeviceName(context),
                icon: const Icon(Icons.save),
                label: const Text('Save'),
              ),
              OutlinedButton(
                onPressed: () => _resetDeviceName(context),
                child: const Text('Use Default'),
              ),
            ],
          ),
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
          _sectionTitle('Local IP Addresses (Advanced)'),
          const SizedBox(height: 8),
          if (addresses.isEmpty)
            const Text('No IP addresses found yet.')
          else
            ...addresses.map((ip) => Text('$ip:${LanSyncService.tcpPort}')),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _lanService.refreshLocalAddresses,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
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
          _sectionTitle('Main Actions'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed:
                    _lanService.isRunning ? null : () => _lanService.start(),
                icon: const Icon(Icons.wifi_tethering),
                label: const Text('Start Sharing'),
              ),
              OutlinedButton.icon(
                onPressed: _lanService.isRunning ? _lanService.stop : null,
                icon: const Icon(Icons.stop),
                label: const Text('Stop'),
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
          const SizedBox(height: 8),
          Text(
            _lanService.isConnected
                ? 'You can sync now.'
                : 'Connect devices on the same Wi-Fi or hotspot, then wait for discovery.',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildLanManualConnectCard(BuildContext context) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Manual Connect (Advanced)'),
          const SizedBox(height: 8),
          TextField(
            controller: _hostController,
            decoration: const InputDecoration(
              labelText: 'Device IP address',
              hintText: 'Example: 192.168.43.21',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _lanService.connectToHost(_hostController.text),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _lanService.connectToHost(_hostController.text),
            icon: const Icon(Icons.link),
            label: const Text('Connect by IP'),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedToggleCard(BuildContext context) {
    return _card(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.tune),
        title: const Text('Advanced tools'),
        subtitle: const Text(
          'Show technical options like manual IP, logs, and Wi-Fi Direct.',
        ),
        trailing: IconButton(
          onPressed: () {
            setState(() {
              _showAdvancedTools = !_showAdvancedTools;
            });
          },
          icon: Icon(
            _showAdvancedTools ? Icons.expand_less : Icons.expand_more,
          ),
          tooltip: _showAdvancedTools
              ? 'Hide advanced tools'
              : 'Show advanced tools',
        ),
      ),
    );
  }

  Widget _buildLanPeersCard(BuildContext context) {
    final peers = _lanService.peers;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Nearby Devices'),
          const SizedBox(height: 8),
          if (peers.isEmpty)
            const Text('No nearby devices found yet.')
          else
            ...peers.map((peer) {
              final isConnected =
                  _lanService.connectedPeerIds.contains(peer.id);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(peer.name),
                subtitle: Text('${peer.address.address}:${peer.port}'),
                trailing: isConnected
                    ? const Text('Connected')
                    : TextButton(
                        onPressed: () => _lanService.connectToHost(
                          peer.address.address,
                          port: peer.port,
                        ),
                        child: const Text('Connect'),
                      ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildLanClientsCard(BuildContext context) {
    final clients = _lanService.connectedPeers;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Connected Devices'),
          const SizedBox(height: 8),
          if (clients.isEmpty)
            const Text('No connected devices yet.')
          else
            ...clients.map(
              (client) => ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(Icons.devices, size: 18),
                title: Text(client),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLanActionsCard(BuildContext context) {
    final allActions = _lanService.actions.reversed.toList();
    final deviceFilters = _buildDeviceFilters(allActions);
    final selectedDevice = deviceFilters.any(
      (filter) => filter.id == _selectedDeviceFilter,
    )
        ? _selectedDeviceFilter
        : _allDevicesFilter;
    final filteredActions = allActions.where((action) {
      if (selectedDevice != _allDevicesFilter &&
          action.deviceId != selectedDevice) {
        return false;
      }
      return _matchesTimeRange(action.timestamp, _selectedTimeRange);
    }).toList();

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Activity Log (Advanced)'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  initialValue: selectedDevice,
                  decoration: const InputDecoration(
                    labelText: 'Device',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: deviceFilters
                      .map(
                        (filter) => DropdownMenuItem<String>(
                          value: filter.id,
                          child: Text(filter.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _selectedDeviceFilter = value;
                    });
                  },
                ),
              ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<LanActionTimeRange>(
                  initialValue: _selectedTimeRange,
                  decoration: const InputDecoration(
                    labelText: 'Time',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: LanActionTimeRange.values
                      .map(
                        (value) => DropdownMenuItem<LanActionTimeRange>(
                          value: value,
                          child: Text(_timeRangeLabel(value)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _selectedTimeRange = value;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${filteredActions.length} action(s)',
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          if (filteredActions.isEmpty)
            Text(
              'No activity found for these filters.',
              style: TextStyle(color: Colors.grey[600]),
            )
          else
            ...filteredActions.take(100).map(
                  (action) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(action.message),
                    subtitle: Text(
                      '${action.deviceName} - ${_formatActionTimestamp(action.timestamp)}',
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  List<_DeviceFilter> _buildDeviceFilters(List<LanSyncAction> actions) {
    final map = <String, String>{};
    for (final action in actions) {
      if (action.deviceId.trim().isEmpty) {
        continue;
      }
      map[action.deviceId] = action.deviceName;
    }

    final filters = [
      const _DeviceFilter(id: _allDevicesFilter, label: 'All devices'),
      ...map.entries
          .map(
            (entry) => _DeviceFilter(
              id: entry.key,
              label: entry.value,
            ),
          )
          .toList()
        ..sort((a, b) => a.label.compareTo(b.label)),
    ];
    return filters;
  }

  bool _matchesTimeRange(DateTime timestamp, LanActionTimeRange range) {
    if (range == LanActionTimeRange.allTime) {
      return true;
    }
    final now = DateTime.now();
    switch (range) {
      case LanActionTimeRange.today:
        return timestamp.year == now.year &&
            timestamp.month == now.month &&
            timestamp.day == now.day;
      case LanActionTimeRange.thisWeek:
        final today = DateTime(now.year, now.month, now.day);
        final weekStart = today.subtract(Duration(days: now.weekday - 1));
        final weekEnd = weekStart.add(const Duration(days: 7));
        return !timestamp.isBefore(weekStart) && timestamp.isBefore(weekEnd);
      case LanActionTimeRange.thisMonth:
        return timestamp.year == now.year && timestamp.month == now.month;
      case LanActionTimeRange.thisYear:
        return timestamp.year == now.year;
      case LanActionTimeRange.allTime:
        return true;
    }
  }

  String _timeRangeLabel(LanActionTimeRange range) {
    switch (range) {
      case LanActionTimeRange.today:
        return 'Today';
      case LanActionTimeRange.thisWeek:
        return 'This week';
      case LanActionTimeRange.thisMonth:
        return 'This month';
      case LanActionTimeRange.thisYear:
        return 'This year';
      case LanActionTimeRange.allTime:
        return 'All time';
    }
  }

  String _formatActionTimestamp(DateTime timestamp) {
    return DateFormat('MMM d, yyyy h:mm a').format(timestamp);
  }

  Future<void> _saveDeviceName(BuildContext context) async {
    await _lanService.setDeviceName(_deviceNameController.text);
    if (!context.mounted) {
      return;
    }
    _deviceNameController.text = _lanService.deviceName;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Device name saved as "${_lanService.deviceName}".'),
      ),
    );
  }

  Future<void> _resetDeviceName(BuildContext context) async {
    await _lanService.setDeviceName('');
    if (!context.mounted) {
      return;
    }
    _deviceNameController.text = _lanService.deviceName;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Device name reset to "${_lanService.deviceName}".'),
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
        fontSize: 14,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.2,
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

class _DeviceFilter {
  const _DeviceFilter({required this.id, required this.label});

  final String id;
  final String label;
}
