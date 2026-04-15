import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../constants/app_theme.dart';
import '../../providers/bluetooth_provider.dart';
import '../../widgets/common_widgets.dart';
import '../../models/heartbeat_data.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _averageHeartRate = 0;
  int _maxHeartRate = 0;
  int _minHeartRate = 0;
  final List<FlSpot> _chartData = [];

  @override
  void initState() {
    super.initState();
    _generateMockChartData();
  }

  void _generateMockChartData() {
    final random = DateTime.now().millisecond;
    for (int i = 0; i < 10; i++) {
      _chartData.add(FlSpot(i.toDouble(), 60 + (random % 40).toDouble()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current Heart Rate Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      'Current Heart Rate',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 16),
                    Consumer<BluetoothProvider>(
                      builder: (context, btProvider, _) {
                        return Column(
                          children: [
                            HeartbeatPulseAnimation(
                              heartRate: btProvider.currentHeartRate > 0
                                  ? btProvider.currentHeartRate
                                  : 75,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '${btProvider.currentHeartRate > 0 ? btProvider.currentHeartRate : 75} BPM',
                              style: Theme.of(context)
                                  .textTheme
                                  .displaySmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            HealthStatusBadge(
                              status: _getHealthStatus(
                                btProvider.currentHeartRate > 0
                                    ? btProvider.currentHeartRate
                                    : 75,
                              ),
                              heartRate: btProvider.currentHeartRate > 0
                                  ? btProvider.currentHeartRate
                                  : 75,
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Heart Rate Chart
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Heart Rate Trend',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 200,
                      child: LineChart(
                        LineChartData(
                          gridData: FlGridData(show: true),
                          titlesData: FlTitlesData(show: true),
                          lineBarsData: [
                            LineChartBarData(
                              spots: _chartData,
                              isCurved: true,
                              color: AppColors.primary,
                              barWidth: 3,
                              isStrokeCapRound: true,
                              dotData: FlDotData(show: true),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Statistics
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    title: 'Average',
                    value: '78 BPM',
                    icon: Icons.trending_up,
                    iconColor: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StatCard(
                    title: 'Max',
                    value: '95 BPM',
                    icon: Icons.arrow_upward,
                    iconColor: AppColors.warning,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StatCard(
                    title: 'Min',
                    value: '62 BPM',
                    icon: Icons.arrow_downward,
                    iconColor: AppColors.info,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Device Status
            Consumer<BluetoothProvider>(
              builder: (context, btProvider, _) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Device Status',
                              style:
                                  Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                            ),
                            Icon(
                              btProvider.connectedDevice != null
                                  ? Icons.bluetooth_connected
                                  : Icons.bluetooth_disabled,
                              color: btProvider.connectedDevice != null
                                  ? AppColors.success
                                  : AppColors.danger,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (btProvider.connectedDevice != null) ...[
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      btProvider.connectedDevice!.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${btProvider.connectedDevice!.signalStrength} dBm',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: AppColors.grey,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () {
                                  btProvider.disconnectDevice();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.danger,
                                ),
                                icon: const Icon(Icons.close),
                                label: const Text('Disconnect'),
                              ),
                            ],
                          ),
                        ] else
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'No device connected',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.pushNamed(
                                          context, '/device-scanner');
                                    },
                                    icon: const Icon(Icons.bluetooth_searching),
                                    label: const Text('Connect Device'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // Start Timed Check
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/timed-check');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: const Icon(Icons.timer),
                label: const Text('Start Timed Health Check'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getHealthStatus(int heartRate) {
    if (heartRate >= 60 && heartRate <= 100) {
      return 'Good';
    } else if (heartRate > 100 && heartRate <= 120) {
      return 'Normal';
    }
    return 'Poor';
  }
}
