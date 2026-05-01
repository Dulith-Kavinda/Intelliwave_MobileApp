import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../constants/app_theme.dart';
import '../../providers/bluetooth_provider.dart';
import '../../utils/test_ecg_data.dart';
import '../../models/ecg_recording_model.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isGraphPlaying = true;
  bool _isRecording = false;
  int _recordingDuration = 300; // 5 minutes default
  int _recordingProgress = 0;
  Timer? _recordingTimer;
  late List<double> _ecgData;
  int _dataIndex = 0;
  Timer? _graphTimer;
  late List<ECGRecording> _pastRecordings;
  String _timeUnit = 'minutes'; // 'seconds', 'minutes', 'hours'
  TextEditingController _durationController = TextEditingController(text: '5');

  @override
  void initState() {
    super.initState();
    _ecgData = TestECGData.getExtendedData(500);
    _pastRecordings = [];
    _startGraphAnimation();
  }

  @override
  void dispose() {
    _graphTimer?.cancel();
    _recordingTimer?.cancel();
    _durationController.dispose();
    super.dispose();
  }

  void _startGraphAnimation() {
    _graphTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (_isGraphPlaying && mounted) {
        setState(() {
          _dataIndex = (_dataIndex + 5) % _ecgData.length;
        });
      }
    });
  }

  void _toggleGraphPlayPause() {
    setState(() {
      _isGraphPlaying = !_isGraphPlaying;
    });
  }

  void _startRecording() {
    _recordingProgress = 0;
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _recordingProgress++;
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
    setState(() {
      _isRecording = false;
    });

    // Create a recording entry
    final recording = ECGRecording(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      deviceName: 'Heart Monitor',
      recordedAt: DateTime.now(),
      durationSeconds: _recordingProgress,
      ecgData: _ecgData,
      healthMetrics: TestECGData.getHealthMetrics(),
    );

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
      body: Consumer<BluetoothProvider>(
        builder: (context, btProvider, _) {
          return SingleChildScrollView(
            child: Column(
              children: [
                // Status Bar - Only show when disconnected or has problem
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
                            'Device not connected. Please connect your ECG device to continue.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.red[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                // Main Content
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ECG Graph
                      _buildECGGraphSection(),
                      const SizedBox(height: 24),
                      // Analytics
                      _buildAnalyticsSection(),
                      const SizedBox(height: 24),
                      // Recording Controls
                      _buildRecordingSection(),
                      const SizedBox(height: 24),
                      // Quick Access
                      _buildQuickAccessSection(),
                      const SizedBox(height: 24),
                      // Past Recordings
                      _buildPastRecordingsSection(),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildECGGraphSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Real-Time ECG Monitor',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: _isGraphPlaying
                    ? Colors.green.withOpacity(0.15)
                    : Colors.grey.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _isGraphPlaying ? '● Live' : '○ Paused',
                style: TextStyle(
                  fontSize: 13,
                  color: _isGraphPlaying ? Colors.green : Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // ECG Graph Container - No Shadow, No Frame
        Container(
          height: 220,
          margin: const EdgeInsets.symmetric(horizontal: 0),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.show_chart,
                  size: 52,
                  color: AppColors.primary.withOpacity(0.3),
                ),
                const SizedBox(height: 14),
                Text(
                  'ECG Waveform Display',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Heart Rate: ${TestECGData.getHealthMetrics()['heartRate']} BPM',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Control Buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            FloatingActionButton.small(
              onPressed: _toggleGraphPlayPause,
              backgroundColor:
                  _isGraphPlaying ? Colors.orange : Colors.green,
              child: Icon(_isGraphPlaying ? Icons.pause : Icons.play_arrow),
            ),
            FloatingActionButton.small(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Opening fullscreen view'),
                  ),
                );
              },
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.fullscreen),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAnalyticsSection() {
    final metrics = TestECGData.getHealthMetrics();
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
          childAspectRatio: 2.5,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildMetricCard(
              'Heart Rate',
              '${metrics['heartRate']} BPM',
              Icons.favorite,
              Colors.red,
            ),
            _buildMetricCard(
              'Blood Pressure',
              '${metrics['systolic']}/${metrics['diastolic']}',
              Icons.favorite_outline,
              Colors.orange,
            ),
            _buildMetricCard(
              'SpO2',
              '${metrics['oxygen']}%',
              Icons.air,
              Colors.blue,
            ),
            _buildMetricCard(
              'Signal Quality',
              metrics['quality'],
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
                color: Colors.grey[700],
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

  Widget _buildRecordingSection() {
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
                color: Colors.white,
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
                      color: Colors.grey[800],
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
                              color: Colors.grey[300]!,
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: TextField(
                            controller: _durationController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2563EB),
                            ),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                              hintText: '5',
                              hintStyle: TextStyle(
                                color: Colors.grey[400],
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
                              color: Colors.grey[300]!,
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            color: Colors.grey[50],
                          ),
                          child: DropdownButton<String>(
                            value: _timeUnit,
                            isExpanded: true,
                            underline: const SizedBox(),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
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
                onPressed: () {
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
                  _isRecording ? 'Stop Recording' : 'Start Recording',
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Navigate to Device Scanner')),
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Navigate to Alerts')),
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
                    color: Colors.grey[300],
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
