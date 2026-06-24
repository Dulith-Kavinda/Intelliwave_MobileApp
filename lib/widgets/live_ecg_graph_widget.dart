import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../providers/index.dart';

class LiveECGGraphWidget extends StatelessWidget {
  final List<int> ecgData;
  final bool isConnected;
  final bool hasError;
  final String? errorMessage;
  final VoidCallback? onFullscreen;
  final VoidCallback? onConnectDevice;
  final bool isFullscreen;

  const LiveECGGraphWidget({
    Key? key,
    required this.ecgData,
    required this.isConnected,
    required this.hasError,
    this.errorMessage,
    this.onFullscreen,
    this.onConnectDevice,
    this.isFullscreen = false,
  }) : super(key: key);

  List<FlSpot> _generateChartSpots() {
    final spots = <FlSpot>[];
    if (ecgData.isEmpty) return spots;

    // Convert last N points to FlSpot for display
    // Use only the most recent points for better visualization
    final displayPoints = ecgData.length > 100 ? ecgData.sublist(ecgData.length - 100) : ecgData;

    for (int i = 0; i < displayPoints.length; i++) {
      // Normalize values to a reasonable range for display
      final normalizedValue = (displayPoints[i] / 255.0) * 100;
      spots.add(FlSpot(i.toDouble(), normalizedValue));
    }

    return spots;
  }

  @override
  Widget build(BuildContext context) {
    if (!isConnected) {
      return _buildDisabledState(context);
    }

    if (hasError) {
      return _buildErrorState(context);
    }

    return _buildGraphCard(context);
  }

  Widget _buildDisabledState(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final screenHeight = MediaQuery.of(context).size.height / 4;
    
    return Container(
      width: double.infinity,
      height: screenHeight,
      decoration: BoxDecoration(
        color: isDarkTheme ? Colors.grey[900] : Colors.grey[50],
      ),
      child: SingleChildScrollView(
        child: SizedBox(
          height: screenHeight,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.bluetooth_disabled,
                size: 64,
                color: isDarkTheme ? Colors.grey[600] : Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No Device Connected',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: isDarkTheme ? AppColors.darkBorder : AppColors.darkBorder2,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Connect a Bluetooth device to view ECG',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDarkTheme ? Colors.grey[400] : Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: onConnectDevice,
                icon: const Icon(Icons.bluetooth_searching),
                label: const Text('Connect Device'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final errorColor = isDarkTheme ? Colors.red[700] : Colors.red[400];
    final screenHeight = MediaQuery.of(context).size.height / 4;
    
    return Container(
      width: double.infinity,
      height: screenHeight,
      decoration: BoxDecoration(
        color: isDarkTheme ? Colors.red[900]?.withOpacity(0.2) : Colors.red[50],
      ),
      child: SingleChildScrollView(
        child: SizedBox(
          height: screenHeight,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: errorColor,
              ),
              const SizedBox(height: 16),
              Text(
                'Error in Getting Data',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: errorColor,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              if (errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    errorMessage!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDarkTheme ? Colors.red[300] : Colors.red[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: onConnectDevice,
                icon: const Icon(Icons.refresh),
                label: const Text('Reconnect Device'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGraphCard(BuildContext context) {
    final spots = _generateChartSpots();
    final screenHeight = MediaQuery.of(context).orientation == Orientation.landscape
        ? 180.0
        : (MediaQuery.of(context).size.height / 4).clamp(160.0, 300.0);

    return SizedBox(
      height: screenHeight,
      child: Card(
        elevation: isFullscreen ? 0 : 0,
        margin: EdgeInsets.zero,
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
                    Text(
                      'Live ECG',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Live',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (onFullscreen != null && !isFullscreen)
                  IconButton(
                    onPressed: onFullscreen,
                    icon: const Icon(Icons.fullscreen),
                    tooltip: 'View fullscreen',
                  )
                else if (isFullscreen)
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.fullscreen_exit),
                    tooltip: 'Exit fullscreen',
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: 99,
                  minY: 0,
                  maxY: 100,
                  backgroundColor: const Color(0xFFFFF2F2),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    horizontalInterval: 2,
                    verticalInterval: 2,
                    getDrawingHorizontalLine: (value) {
                      final isMajor = (value.round() % 10) == 0;
                      return FlLine(
                        color: isMajor 
                            ? const Color(0xFFFF9494).withOpacity(0.8) 
                            : const Color(0xFFFFD1D1).withOpacity(0.55),
                        strokeWidth: isMajor ? 1.0 : 0.5,
                      );
                    },
                    getDrawingVerticalLine: (value) {
                      final isMajor = (value.round() % 10) == 0;
                      return FlLine(
                        color: isMajor 
                            ? const Color(0xFFFF9494).withOpacity(0.8) 
                            : const Color(0xFFFFD1D1).withOpacity(0.55),
                        strokeWidth: isMajor ? 1.0 : 0.5,
                      );
                    },
                  ),
                  titlesData: const FlTitlesData(
                    show: false,
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots.isEmpty
                          ? [const FlSpot(0, 50)]
                          : spots,
                      isCurved: true,
                      color: const Color(0xFF1E1E1E), // Dark charcoal ECG line trace
                      barWidth: 1.5,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(show: false),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Data points: ${ecgData.length}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

/// Full screen ECG graph display
class FullscreenECGGraph extends StatelessWidget {
  final List<int>? ecgData;
  final bool? isConnected;
  final bool? hasError;
  final String? errorMessage;

  const FullscreenECGGraph({
    Key? key,
    this.ecgData,
    this.isConnected,
    this.hasError,
    this.errorMessage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live ECG'),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Consumer2<BluetoothProvider, ECGProvider>(
          builder: (context, btProvider, ecgProvider, _) {
            return LiveECGGraphWidget(
              ecgData: ecgProvider.ecgData,
              isConnected: btProvider.isConnected,
              hasError: ecgProvider.hasDataError,
              errorMessage: ecgProvider.errorMessage,
              isFullscreen: true,
            );
          },
        ),
      ),
    );
  }
}
