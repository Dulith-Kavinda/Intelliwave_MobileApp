import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/heartbeat_data.dart';

/// ECG Chart Widget - Displays heart rate data as a line chart
class ECGChartWidget extends StatelessWidget {
  final HeartbeatData data;
  final double height;

  const ECGChartWidget({
    Key? key,
    required this.data,
    this.height = 300,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Heart Rate',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${data.heartRate} BPM',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Chip(
                  label: Text(data.status.toUpperCase()),
                  backgroundColor: _getStatusColor(data.status),
                  labelStyle: const TextStyle(color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: height,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    horizontalInterval: 20,
                    verticalInterval: 1,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey[300],
                        strokeWidth: 0.5,
                      );
                    },
                    getDrawingVerticalLine: (value) {
                      return FlLine(
                        color: Colors.grey[300],
                        strokeWidth: 0.5,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 5,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toInt()}',
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 20,
                        reservedSize: 35,
                      ),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(
                      color: Colors.grey[300]!,
                      width: 1,
                    ),
                  ),
                  minX: 0,
                  maxX: 60,
                  minY: 40,
                  maxY: 150,
                  lineBarsData: [
                    LineChartBarData(
                      spots: _generateECGSpots(data.heartRate),
                      isCurved: true,
                      color: _getHeartRateColor(data.heartRate),
                      barWidth: 2,
                      isStrokeCapRound: true,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: _getHeartRateColor(data.heartRate).withOpacity(0.3),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                        return touchedBarSpots.map((barSpot) {
                          return LineTooltipItem(
                            '${barSpot.y.toStringAsFixed(0)} BPM',
                            const TextStyle(color: Colors.white),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Time: ${data.timestamp.toString().split('.')[0]}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  'Device: ${data.deviceId}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Generate ECG data points based on heart rate
  List<FlSpot> _generateECGSpots(int heartRate) {
    final List<FlSpot> spots = [];
    final baselineVariation = (heartRate - 60).toDouble();
    
    for (int i = 0; i < 60; i++) {
      // Add some variation to simulate ECG waveform
      final variation = (i % 10) < 5 ? baselineVariation * 0.5 : -baselineVariation * 0.3;
      final yValue = 60 + baselineVariation + variation + (i * 0.3 % 10);
      spots.add(FlSpot(i.toDouble(), yValue.clamp(40, 150)));
    }
    
    return spots;
  }

  /// Get color based on heart rate
  Color _getHeartRateColor(int heartRate) {
    if (heartRate < 60) return Colors.blue;
    if (heartRate < 100) return Colors.green;
    if (heartRate < 120) return Colors.orange;
    return Colors.red;
  }

  /// Get status chip color
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'good':
        return Colors.green;
      case 'normal':
        return Colors.blue;
      case 'high':
        return Colors.orange;
      case 'warning':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
