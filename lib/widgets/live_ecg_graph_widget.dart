import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../constants/app_theme.dart';

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
                      color: isDarkTheme ? Colors.grey[300] : Colors.grey[700],
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
    final screenHeight = MediaQuery.of(context).size.height / 4;

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
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    horizontalInterval: 20,
                    verticalInterval: 10,
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
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: spots.length > 50 ? spots.length / 5 : 10,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        interval: 20,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots.isEmpty
                          ? [const FlSpot(0, 0)]
                          : spots,
                      isCurved: true,
                      color: AppColors.primary,
                      barWidth: 2,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: spots.length < 20,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 3,
                            color: AppColors.primary,
                            strokeWidth: 1,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.primary.withOpacity(0.1),
                      ),
                    ),
                  ],
                  minY: 0,
                  maxY: 100,
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
  final List<int> ecgData;
  final bool isConnected;
  final bool hasError;
  final String? errorMessage;

  const FullscreenECGGraph({
    Key? key,
    required this.ecgData,
    required this.isConnected,
    required this.hasError,
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
        child: LiveECGGraphWidget(
          ecgData: ecgData,
          isConnected: isConnected,
          hasError: hasError,
          errorMessage: errorMessage,
          isFullscreen: true,
        ),
      ),
    );
  }
}
