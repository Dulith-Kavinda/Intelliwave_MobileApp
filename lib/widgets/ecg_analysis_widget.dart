import 'package:flutter/material.dart';
import '../constants/app_theme.dart';

class ECGAnalysisWidget extends StatelessWidget {
  final List<int> ecgData;
  final bool isConnected;
  final bool hasError;

  const ECGAnalysisWidget({
    Key? key,
    required this.ecgData,
    required this.isConnected,
    required this.hasError,
  }) : super(key: key);

  Map<String, dynamic> _calculateMetrics() {
    if (ecgData.isEmpty || !isConnected || hasError) {
      return {
        'heartRate': '--',
        'avgSignal': '--',
        'maxSignal': '--',
        'minSignal': '--',
        'signalQuality': '--',
        'dataPoints': 0,
      };
    }

    // Calculate metrics
    final max = ecgData.reduce((a, b) => a > b ? a : b);
    final min = ecgData.reduce((a, b) => a < b ? a : b);
    final avg = (ecgData.reduce((a, b) => a + b) / ecgData.length).toInt();
    final dataPoints = ecgData.length;

    // Estimate heart rate (assuming ~200 samples per second at 60 BPM = ~200 samples per beat)
    // This is a simplified estimation - actual HR calculation would need peak detection
    final estimatedHeartRate = (dataPoints / 200 * 60).toInt().clamp(0, 200);

    // Calculate signal quality (0-100%) based on data variance
    final variance = ecgData
        .map((e) => (e - avg) * (e - avg))
        .reduce((a, b) => a + b) ~/
        ecgData.length;
    final signalQuality = (variance / 1000 * 100).toInt().clamp(0, 100);

    return {
      'heartRate': estimatedHeartRate,
      'avgSignal': avg,
      'maxSignal': max,
      'minSignal': min,
      'signalQuality': signalQuality,
      'dataPoints': dataPoints,
    };
  }

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final metrics = _calculateMetrics();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkTheme ? Colors.grey[850] : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkTheme ? Colors.grey[700]! : Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Live Analysis',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDarkTheme ? Colors.grey[200] : Colors.grey[800],
                ),
          ),
          const SizedBox(height: 12),

          // Analysis Grid
          if (isConnected && !hasError)
            GridView.count(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildMetricCard(
                  context,
                  'Heart Rate',
                  '${metrics['heartRate']}',
                  'BPM',
                  AppColors.primary,
                  isDarkTheme,
                ),
                _buildMetricCard(
                  context,
                  'Avg Signal',
                  '${metrics['avgSignal']}',
                  'mV',
                  AppColors.success,
                  isDarkTheme,
                ),
                _buildMetricCard(
                  context,
                  'Data Points',
                  '${metrics['dataPoints']}',
                  'pts',
                  AppColors.warning,
                  isDarkTheme,
                ),
                _buildMetricCard(
                  context,
                  'Max Signal',
                  '${metrics['maxSignal']}',
                  'mV',
                  Colors.blue,
                  isDarkTheme,
                ),
                _buildMetricCard(
                  context,
                  'Min Signal',
                  '${metrics['minSignal']}',
                  'mV',
                  Colors.orange,
                  isDarkTheme,
                ),
                _buildMetricCard(
                  context,
                  'Quality',
                  '${metrics['signalQuality']}',
                  '%',
                  AppColors.info,
                  isDarkTheme,
                ),
              ],
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: isDarkTheme ? Colors.grey[800] : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  'Connect device to view analysis',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDarkTheme ? Colors.grey[500] : Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context,
    String label,
    String value,
    String unit,
    Color color,
    bool isDarkTheme,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDarkTheme ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isDarkTheme ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 10,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            textBaseline: TextBaseline.alphabetic,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                      fontSize: 14,
                    ),
              ),
              const SizedBox(width: 2),
              Text(
                unit,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: color.withOpacity(0.8),
                      fontSize: 9,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
