import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';
import '../constants/app_theme.dart';

/// Global ECG Graph Widget for displaying real-time ECG data
class EcgGraphWidget extends StatefulWidget {
  final List<int> ecgData;
  final bool isConnected;
  final bool hasError;
  final String? errorMessage;
  final VoidCallback? onFullscreen;
  final VoidCallback? onConnectDevice;
  final bool showTestData;

  const EcgGraphWidget({
    Key? key,
    required this.ecgData,
    this.isConnected = false,
    this.hasError = false,
    this.errorMessage,
    this.onFullscreen,
    this.onConnectDevice,
    this.showTestData = true,
  }) : super(key: key);

  @override
  State<EcgGraphWidget> createState() => _EcgGraphWidgetState();
}

class _EcgGraphWidgetState extends State<EcgGraphWidget> {
  late List<int> _displayData;
  late List<int> _testECGData;
  late Timer _animationTimer;
  int _testDataIndex = 0;
  
  // ECG sampling rate: 250 Hz (typical for medical ECG devices)
  // Animation interval: 20ms (50Hz animation) = 5 samples per frame
  static const int samplesPerFrame = 5;
  static const int animationIntervalMs = 20;

  @override
  void initState() {
    super.initState();
    _testECGData = _getRealisticECGData();
    _initializeDisplayData();
    _startAnimationLoop();
  }

  @override
  void didUpdateWidget(EcgGraphWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ecgData != oldWidget.ecgData && widget.ecgData.isNotEmpty) {
      _updateDisplayData();
    }
  }

  void _initializeDisplayData() {
    if (widget.ecgData.isNotEmpty) {
      _displayData = List.from(widget.ecgData);
    } else if (widget.showTestData) {
      _displayData = [];
    } else {
      _displayData = [];
    }
  }

  void _updateDisplayData() {
    if (widget.ecgData.isNotEmpty) {
      _displayData = List.from(widget.ecgData);
    }
  }

  void _startAnimationLoop() {
    // Animate at 50Hz (20ms per frame), adding 5 samples per frame
    // This creates smooth animation at realistic ECG speed
    _animationTimer = Timer.periodic(Duration(milliseconds: animationIntervalMs), (timer) {
      setState(() {
        // If using real ECG data from device, use that; otherwise use test data loop
        if (widget.ecgData.isNotEmpty) {
          // Real device data
          _displayData = List.from(widget.ecgData);
        } else {
          // Test data loop - continuously cycle through test data
          if (_displayData.length < 500) {
            // Build up initial data (2 seconds worth at 250Hz)
            for (int i = 0; i < samplesPerFrame && _testDataIndex < _testECGData.length * 10; i++) {
              _displayData.add(_testECGData[_testDataIndex % _testECGData.length]);
              _testDataIndex++;
            }
          } else {
            // Maintain rolling window
            _displayData.removeRange(0, samplesPerFrame);
            for (int i = 0; i < samplesPerFrame; i++) {
              _displayData.add(_testECGData[_testDataIndex % _testECGData.length]);
              _testDataIndex++;
            }
          }
        }
      });
    });
  }

  /// Realistic human heart ECG waveform data (P-QRS-T wave pattern)
  /// This represents one complete heartbeat cycle at ~60 BPM
  List<int> _getRealisticECGData() {
    return [
      // Baseline
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      // P wave (atrial depolarization)
      5, 15, 25, 30, 25, 15, 5, 0, -5, -10,
      // P-R interval (isoelectric)
      -5, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      // Q wave (first negative deflection)
      -5, -15, -25, -20, -10, 0,
      // R wave (major positive deflection)
      10, 50, 100, 150, 180, 200, 180, 150, 100, 50,
      // S wave (negative deflection)
      10, -20, -50, -80, -100, -120, -100, -80, -50, -20,
      // S-T segment (isoelectric)
      0, 0, 0, 0, 0, 0, 0, 0,
      // T wave (ventricular repolarization)
      5, 20, 35, 45, 50, 45, 35, 20, 5, 0,
      // T-P interval (isoelectric baseline)
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    ];
  }

  List<FlSpot> _generateChartSpots() {
    final spots = <FlSpot>[];
    if (_displayData.isEmpty) return spots;

    for (int i = 0; i < _displayData.length; i++) {
      spots.add(FlSpot(i.toDouble(), _displayData[i].toDouble()));
    }

    return spots;
  }

  double _getMinValue(List<FlSpot> spots) {
    if (spots.isEmpty) return -150;
    return spots.map((spot) => spot.y).reduce((a, b) => a < b ? a : b) - 30;
  }

  double _getMaxValue(List<FlSpot> spots) {
    if (spots.isEmpty) return 250;
    return spots.map((spot) => spot.y).reduce((a, b) => a > b ? a : b) + 30;
  }

  /// Get time label in seconds
  String _getTimeLabel(double samplesCount) {
    final seconds = (samplesCount / 250.0).toStringAsFixed(1);
    return '${seconds}s';
  }

  @override
  void dispose() {
    _animationTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.hasError) {
      return _buildErrorState(context);
    }

    return Column(
      children: [
        _buildGraph(context),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(right: 16, bottom: 8),
          child: Align(
            alignment: Alignment.bottomRight,
            child: IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FullscreenEcgGraph(
                      ecgData: _displayData,
                      isConnected: widget.isConnected,
                      hasError: widget.hasError,
                      errorMessage: widget.errorMessage,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.fullscreen),
              tooltip: 'Fullscreen',
              iconSize: 24,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final errorColor = isDarkTheme ? Colors.red[700] : Colors.red[400];

    return Container(
      width: double.infinity,
      height: 300,
      decoration: BoxDecoration(
        color: isDarkTheme ? Colors.red[900]?.withOpacity(0.2) : Colors.red[50],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 56,
            color: errorColor,
          ),
          const SizedBox(height: 16),
          Text(
            'Error Getting ECG Data',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: errorColor,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          if (widget.errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                widget.errorMessage!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isDarkTheme ? Colors.red[300] : Colors.red[600],
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGraph(BuildContext context) {
    final spots = _generateChartSpots();
    final minY = _getMinValue(spots);
    final maxY = _getMaxValue(spots);

    return SizedBox(
      width: double.infinity,
      height: 300,
      child: Padding(
        padding: const EdgeInsets.only(top: 16, right: 5),
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: true,
              horizontalInterval: 50,
              verticalInterval: spots.length > 50 ? spots.length / 5 : 10,
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
                  reservedSize: 40,
                  interval: spots.length > 50 ? spots.length / 5 : 50,
                  getTitlesWidget: (value, meta) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _getTimeLabel(value),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  interval: 50,
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
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: spots.isEmpty ? [const FlSpot(0, 0)] : spots,
                isCurved: true,
                color: AppColors.primary,
                barWidth: 2,
                isStrokeCapRound: true,
                dotData: FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: AppColors.primary.withOpacity(0.1),
                ),
              ),
            ],
            minY: minY,
            maxY: maxY,
          ),
        ),
      ),
    );
  }
}

/// Full screen ECG graph display
class FullscreenEcgGraph extends StatefulWidget {
  final List<int> ecgData;
  final bool isConnected;
  final bool hasError;
  final String? errorMessage;

  const FullscreenEcgGraph({
    Key? key,
    required this.ecgData,
    this.isConnected = false,
    this.hasError = false,
    this.errorMessage,
  }) : super(key: key);

  @override
  State<FullscreenEcgGraph> createState() => _FullscreenEcgGraphState();
}

class _FullscreenEcgGraphState extends State<FullscreenEcgGraph> {
  late List<int> _displayData;
  late List<int> _testECGData;
  late Timer _animationTimer;
  int _testDataIndex = 0;

  static const int samplesPerFrame = 5;
  static const int animationIntervalMs = 20;

  @override
  void initState() {
    super.initState();
    _testECGData = _getRealisticECGData();
    _displayData = List.from(widget.ecgData);
    _startAnimationLoop();
  }

  void _startAnimationLoop() {
    _animationTimer = Timer.periodic(Duration(milliseconds: animationIntervalMs), (timer) {
      setState(() {
        if (widget.ecgData.isNotEmpty) {
          _displayData = List.from(widget.ecgData);
        } else {
          if (_displayData.length < 500) {
            for (int i = 0; i < samplesPerFrame && _testDataIndex < _testECGData.length * 10; i++) {
              _displayData.add(_testECGData[_testDataIndex % _testECGData.length]);
              _testDataIndex++;
            }
          } else {
            _displayData.removeRange(0, samplesPerFrame);
            for (int i = 0; i < samplesPerFrame; i++) {
              _displayData.add(_testECGData[_testDataIndex % _testECGData.length]);
              _testDataIndex++;
            }
          }
        }
      });
    });
  }

  List<int> _getRealisticECGData() {
    return [
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      5, 15, 25, 30, 25, 15, 5, 0, -5, -10,
      -5, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      -5, -15, -25, -20, -10, 0,
      10, 50, 100, 150, 180, 200, 180, 150, 100, 50,
      10, -20, -50, -80, -100, -120, -100, -80, -50, -20,
      0, 0, 0, 0, 0, 0, 0, 0,
      5, 20, 35, 45, 50, 45, 35, 20, 5, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    ];
  }

  List<FlSpot> _generateChartSpots() {
    final spots = <FlSpot>[];
    if (_displayData.isEmpty) return spots;

    for (int i = 0; i < _displayData.length; i++) {
      spots.add(FlSpot(i.toDouble(), _displayData[i].toDouble()));
    }

    return spots;
  }

  double _getMinValue(List<FlSpot> spots) {
    if (spots.isEmpty) return -150;
    return spots.map((spot) => spot.y).reduce((a, b) => a < b ? a : b) - 30;
  }

  double _getMaxValue(List<FlSpot> spots) {
    if (spots.isEmpty) return 250;
    return spots.map((spot) => spot.y).reduce((a, b) => a > b ? a : b) + 30;
  }

  String _getTimeLabel(double samplesCount) {
    final seconds = (samplesCount / 250.0).toStringAsFixed(1);
    return '${seconds}s';
  }

  @override
  void dispose() {
    _animationTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spots = _generateChartSpots();
    final minY = _getMinValue(spots);
    final maxY = _getMaxValue(spots);

    return Scaffold(
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  horizontalInterval: 50,
                  verticalInterval: spots.length > 50 ? spots.length / 5 : 10,
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
                      reservedSize: 40,
                      interval: spots.length > 50 ? spots.length / 5 : 50,
                      getTitlesWidget: (value, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _getTimeLabel(value),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50,
                      interval: 50,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                            fontSize: 12,
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
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots.isEmpty ? [const FlSpot(0, 0)] : spots,
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.primary.withOpacity(0.1),
                    ),
                  ),
                ],
                minY: minY,
                maxY: maxY,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
