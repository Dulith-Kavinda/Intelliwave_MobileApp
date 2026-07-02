import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../constants/app_theme.dart';
import '../../providers/bluetooth_provider.dart';
import '../../providers/ecg_provider.dart';
import '../../models/ecg_recording_model.dart';
import '../../widgets/live_ecg_graph_widget.dart';
import '../../utils/service_locator.dart';
import 'device_scanner_screen.dart';
import 'notifications_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isRecording = false;
  int _recordingDuration = 300; // 5 minutes default
  int _recordingProgress = 0;
  Timer? _recordingTimer;
  StreamSubscription<List<int>>? _ecgRecordingSubscription;
  final List<double> _recordedEcgData = [];
  final List<int> _recordedHeartRates = [];
  late List<ECGRecording> _pastRecordings;
  String _timeUnit = 'minutes'; // 'seconds', 'minutes', 'hours'
  final TextEditingController _durationController = TextEditingController(text: '5');

  @override
  void initState() {
    super.initState();
    _pastRecordings = storageService.getECGRecordings();
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _ecgRecordingSubscription?.cancel();
    _durationController.dispose();
    super.dispose();
  }

  void _startRecording() {
    _recordedEcgData.clear();
    _recordedHeartRates.clear();

    _ecgRecordingSubscription = bluetoothService.ecgDataStream.listen((data) {
      if (mounted) {
        _recordedEcgData.addAll(data.map((e) => e.toDouble()));
      }
    });

    _recordingProgress = 0;
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _recordingProgress++;

        final btProvider = Provider.of<BluetoothProvider>(context, listen: false);
        if (btProvider.isConnected && btProvider.currentHeartRate > 0) {
          _recordedHeartRates.add(btProvider.currentHeartRate);
        }

        if (_recordingProgress >= _recordingDuration) {
          _stopRecording();
        }
      });
    });
    setState(() {
      _isRecording = true;
    });
  }

  void _stopRecording() {
    _recordingTimer?.cancel();
    _ecgRecordingSubscription?.cancel();
    _ecgRecordingSubscription = null;

    setState(() {
      _isRecording = false;
    });

    int avgHeartRate = 0;
    if (_recordedHeartRates.isNotEmpty) {
      avgHeartRate = (_recordedHeartRates.reduce((a, b) => a + b) / _recordedHeartRates.length).toInt();
    } else {
      final btProvider = Provider.of<BluetoothProvider>(context, listen: false);
      avgHeartRate = btProvider.currentHeartRate;
    }

    final btProvider = Provider.of<BluetoothProvider>(context, listen: false);
    final deviceName = btProvider.connectedDevice?.name ?? 'Heart Monitor';

    final recording = ECGRecording(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      deviceName: deviceName,
      recordedAt: DateTime.now(),
      durationSeconds: _recordingProgress,
      ecgData: List.from(_recordedEcgData),
      healthMetrics: {
        'heartRate': avgHeartRate,
        'quality': _recordedEcgData.isNotEmpty ? 'Good' : 'No Data',
        'systolic': '--',
        'diastolic': '--',
        'oxygen': '--',
      },
    );

    storageService.saveECGRecording(recording);
    setState(() {
      _pastRecordings.insert(0, recording);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ECG Recording saved successfully'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  int _getSecondsFromInput() {
    final value = int.tryParse(_durationController.text) ?? 5;
    switch (_timeUnit) {
      case 'seconds':
        return value < 15 ? 15 : value; // Minimum 15 seconds
      case 'minutes':
        return value * 60;
      case 'hours':
        return value * 3600;
      default:
        return value * 60;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.pushNamed(context, '/ecg_recordings');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Status bar + live ECG + metrics (rebuilds on BT data change)
            Consumer2<BluetoothProvider, ECGProvider>(
              builder: (context, btProvider, ecgProvider, _) {
                return Column(
                  children: [
                    // Status Bar - Only show when disconnected
                    if (!btProvider.isConnected)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.15),
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.red.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_rounded,
                              color: Colors.red[700],
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'No device connected. Power on your HM-10 module, then tap the Bluetooth icon to connect.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.red[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            // Quick connect button
                            TextButton.icon(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const DeviceScannerScreen()),
                              ),
                              icon: const Icon(Icons.bluetooth_searching,
                                  size: 16, color: Colors.red),
                              label: Text('Connect',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.red[700])),
                              style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4)),
                            ),
                          ],
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ECG Graph — RepaintBoundary prevents full page repaint
                          RepaintBoundary(
                            child: _buildECGGraphSection(btProvider, ecgProvider),
                          ),
                          const SizedBox(height: 24),
                          // Analytics metrics
                          _buildAnalyticsSection(btProvider, ecgProvider),
                          const SizedBox(height: 24),
                          // Recording Controls
                          _buildRecordingSection(btProvider),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            // Static sections — never rebuild from BT data
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: Column(
                children: [
                  _buildQuickAccessSection(),
                  const SizedBox(height: 24),
                  _buildPastRecordingsSection(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildECGGraphSection(BluetoothProvider btProvider, ECGProvider ecgProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Real-Time ECG Monitor',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // HM-10 connection badge
            if (btProvider.isConnected && btProvider.isHM10Device)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF00C853).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color:
                          const Color(0xFF00C853).withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF00C853),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'HM-10 Serial',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF00C853),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        LiveECGGraphWidget(
          ecgData: ecgProvider.ecgData,
          isConnected: btProvider.isConnected,
          hasError: ecgProvider.hasDataError,
          errorMessage: ecgProvider.errorMessage,
          onConnectDevice: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DeviceScannerScreen()),
            );
          },
          onFullscreen: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const FullscreenECGGraph(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAnalyticsSection(BluetoothProvider btProvider, ECGProvider ecgProvider) {
    final hasRealHeartRate = btProvider.isConnected && btProvider.currentHeartRate > 0;
    final heartRateStr = hasRealHeartRate ? '${btProvider.currentHeartRate} BPM' : '--';
    final bpStr = btProvider.isConnected ? 'N/A' : '--';
    final oxygenStr = btProvider.isConnected ? 'N/A' : '--';
    final signalQualityStr = btProvider.isConnected 
        ? (ecgProvider.hasDataError ? 'Poor' : 'Good') 
        : '--';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Current Health Metrics',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          childAspectRatio: 2.0,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildMetricCard(
              'Heart Rate',
              heartRateStr,
              Icons.favorite,
              Colors.red,
            ),
            _buildMetricCard(
              'Blood Pressure',
              bpStr,
              Icons.favorite_outline,
              Colors.orange,
            ),
            _buildMetricCard(
              'SpO2',
              oxygenStr,
              Icons.air,
              Colors.blue,
            ),
            _buildMetricCard(
              'Signal Quality',
              signalQualityStr,
              Icons.signal_cellular_alt,
              Colors.green,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(12),
        color: color.withOpacity(0.06),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkTextSecondary
                    : Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 1),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingSection(BluetoothProvider btProvider) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.08),
            AppColors.primary.withOpacity(0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.fiber_manual_record,
                  color: _isRecording ? Colors.red : AppColors.primary,
                  size: 24,
                ),
                const SizedBox(width: 10),
                const Text(
                  'ECG Recording',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Modern Time Duration Picker
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkSurface2
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Set Recording Duration',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.darkTextSecondary
                          : Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      // Duration Input
                      Expanded(
                        flex: 2,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? AppColors.darkBorder
                                  : Colors.grey[300]!,
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: TextField(
                            controller: _durationController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? AppColors.primaryLight
                                  : const Color(0xFF2563EB),
                            ),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                              hintText: '5',
                              hintStyle: TextStyle(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? AppColors.darkTextMuted
                                    : Colors.grey[400],
                              ),
                            ),
                            onChanged: (value) {
                              setState(() {
                                _recordingDuration = _getSecondsFromInput();
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Time Unit Dropdown
                      Expanded(
                        flex: 2,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? AppColors.darkBorder
                                  : Colors.grey[300]!,
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            color: Theme.of(context).brightness == Brightness.dark
                                ? AppColors.darkSurface3
                                : Colors.grey[50],
                          ),
                          child: DropdownButton<String>(
                            value: _timeUnit,
                            isExpanded: true,
                            underline: const SizedBox(),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            dropdownColor: Theme.of(context).brightness == Brightness.dark
                                ? AppColors.darkSurface3
                                : Colors.white,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                            items: ['seconds', 'minutes', 'hours']
                                .map((unit) => DropdownMenuItem(
                                      value: unit,
                                      child: Text(unit),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _timeUnit = value;
                                  _recordingDuration = _getSecondsFromInput();
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Display formatted time
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          _formatDuration(_recordingDuration),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '⚠ Minimum duration: 15 seconds',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.amber[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            // Recording Progress
            if (_isRecording)
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.red.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.fiber_manual_record,
                              color: Colors.red,
                              size: 12,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Recording in progress...',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: _recordingProgress / _recordingDuration,
                            minHeight: 10,
                            backgroundColor: Colors.red.withOpacity(0.2),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.red,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(_recordingProgress),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                            Text(
                              _formatDuration(_recordingDuration),
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            // Record Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: !btProvider.isConnected
                    ? null
                    : () {
                        // Validate minimum 15 seconds
                        if (!_isRecording &&
                            _recordingDuration < 15) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Recording duration must be at least 15 seconds',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        if (_isRecording) {
                          _stopRecording();
                        } else {
                          _startRecording();
                        }
                      },
                icon: Icon(
                  _isRecording ? Icons.stop_circle : Icons.fiber_manual_record,
                  size: 22,
                ),
                label: Text(
                  !btProvider.isConnected
                      ? 'Connect Device to Record'
                      : _isRecording
                          ? 'Stop Recording'
                          : 'Start Recording',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _isRecording ? Colors.red : AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAccessSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Access',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          childAspectRatio: 1.2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildQuickActionCard(
              'Connect Device',
              Icons.bluetooth,
              Colors.blue,
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DeviceScannerScreen()),
                );
              },
            ),
            _buildQuickActionCard(
              'Recordings',
              Icons.history,
              Colors.purple,
              () {
                Navigator.pushNamed(context, '/ecg_recordings');
              },
            ),
            _buildQuickActionCard(
              'Alerts',
              Icons.notifications,
              Colors.orange,
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                );
              },
            ),
            _buildQuickActionCard(
              'Settings',
              Icons.settings,
              Colors.grey,
              () {
                Navigator.pushNamed(context, '/settings');
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionCard(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPastRecordingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Recordings',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/ecg_recordings');
              },
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_pastRecordings.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Icon(
                    Icons.folder_open,
                    size: 48,
                    color: AppColors.darkBorder,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No recordings yet',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _pastRecordings.take(3).length,
            itemBuilder: (context, index) {
              final recording = _pastRecordings[index];
              return Card(
                elevation: 1,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(
                    Icons.favorite,
                    color: AppColors.primary,
                  ),
                  title: Text(
                    recording.deviceName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${recording.getFormattedDate()} • ${recording.getFormattedDuration()}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey[400],
                  ),
                  onTap: () {
                    Navigator.pushNamed(context, '/ecg_recordings');
                  },
                ),
              );
            },
          ),
      ],
    );
  }
}
