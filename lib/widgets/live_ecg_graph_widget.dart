import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'dart:async';
import '../constants/app_theme.dart';
import '../providers/index.dart';
import '../utils/service_locator.dart';

// ECG Painter
class ECGPainter extends CustomPainter {
  final List<double> samples;
  final double scrollOffset;
  final Color lineColor;
  final Color gridMajorColor;
  final Color gridMinorColor;
  final Color bgColor;
  final double pixelsPerSample;

  const ECGPainter({
    required this.samples,
    required this.scrollOffset,
    required this.lineColor,
    required this.gridMajorColor,
    required this.gridMinorColor,
    required this.bgColor,
    required this.pixelsPerSample,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = bgColor);
    _drawGrid(canvas, size);
    _drawWaveform(canvas, size);
  }

  void _drawGrid(Canvas canvas, Size size) {
    final minorPaint = Paint()
      ..color = gridMinorColor
      ..strokeWidth = 0.5;
    final majorPaint = Paint()
      ..color = gridMajorColor
      ..strokeWidth = 1.0;
    const smallPx = 10.0;
    const bigPx = 50.0;
    final startX = -(scrollOffset % bigPx);
    for (double x = startX; x <= size.width + bigPx; x += smallPx) {
      final offset = (x - startX + scrollOffset) % bigPx;
      final isMajor = offset < 0.6 || (bigPx - offset) < 0.6;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height),
          isMajor ? majorPaint : minorPaint);
    }
    for (double y = 0; y <= size.height; y += smallPx) {
      final isMajor = (y % bigPx) < 0.6 || (bigPx - (y % bigPx)) < 0.6;
      canvas.drawLine(Offset(0, y), Offset(size.width, y),
          isMajor ? majorPaint : minorPaint);
    }
  }

  void _drawWaveform(Canvas canvas, Size size) {
    if (samples.isEmpty) return;
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final path = Path();
    bool started = false;
    final visibleSamples = (size.width / pixelsPerSample).ceil() + 2;
    final startIdx = math.max(0, samples.length - visibleSamples);
    final writeHeadX = math.min(scrollOffset, size.width);
    for (int i = startIdx; i < samples.length; i++) {
      final fromEnd = samples.length - 1 - i;
      final x = writeHeadX - fromEnd * pixelsPerSample;
      if (x < 0) continue;
      final y = size.height * (1.0 - samples[i]);
      if (!started) {
        path.moveTo(x, y);
        started = true;
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
    if (started) {
      canvas.drawLine(
        Offset(writeHeadX, 0),
        Offset(writeHeadX, size.height),
        Paint()
          ..color = lineColor.withValues(alpha: 0.30)
          ..strokeWidth = 1.2,
      );
    }
  }

  @override
  bool shouldRepaint(ECGPainter old) {
    // Repaint only when visible data actually changed
    return old.samples.length != samples.length ||
        old.scrollOffset != scrollOffset ||
        old.lineColor != lineColor ||
        old.bgColor != bgColor;
  }
}

// LiveECGGraphWidget
class LiveECGGraphWidget extends StatefulWidget {
  final List<int> ecgData;
  final bool isConnected;
  final bool hasError;
  final String? errorMessage;
  final VoidCallback? onFullscreen;
  final VoidCallback? onConnectDevice;
  final bool isFullscreen;

  const LiveECGGraphWidget({
    super.key,
    required this.ecgData,
    required this.isConnected,
    required this.hasError,
    this.errorMessage,
    this.onFullscreen,
    this.onConnectDevice,
    this.isFullscreen = false,
  });

  @override
  State<LiveECGGraphWidget> createState() => _LiveECGGraphWidgetState();
}

class _LiveECGGraphWidgetState extends State<LiveECGGraphWidget>
    with SingleTickerProviderStateMixin {
  final List<double> _samples = [];
  double _scrollOffset = 0;
  static const double _pixelsPerSample = 3.0;
  static const int _maxSamples = 3000;
  late AnimationController _blinkController;
  StreamSubscription<List<int>>? _ecgSubscription;

  // ── Frame-rate cap ─────────────────────────────────────────────────────────
  // Incoming BLE packets can arrive at ~100 Hz, but the display runs at 60 Hz.
  // We accumulate samples in _pendingChunk without calling setState, then flush
  // exactly once per frame via addPostFrameCallback — capping repaints at 60 Hz.
  final List<double> _pendingChunk = [];
  bool _frameCallbackScheduled = false;

  void _schedulePendingFlush() {
    if (_frameCallbackScheduled) return;
    _frameCallbackScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _frameCallbackScheduled = false;
      if (!mounted || _pendingChunk.isEmpty) return;
      setState(() {
        _samples.addAll(_pendingChunk);
        _scrollOffset += _pendingChunk.length * _pixelsPerSample;
        _pendingChunk.clear();
        if (_samples.length > _maxSamples) {
          _samples.removeRange(0, _samples.length - _maxSamples);
        }
      });
    });
  }

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..repeat(reverse: true);

    // Warm up samples from initial provider data
    _samples.addAll(
        widget.ecgData.map((val) => val.clamp(0, 255).toDouble() / 255.0));
    _scrollOffset = _samples.length * _pixelsPerSample;

    // Subscribe to raw BLE stream — accumulate, never setState directly
    _ecgSubscription = bluetoothService.ecgDataStream.listen((chunk) {
      if (mounted && widget.isConnected && !widget.hasError) {
        for (final val in chunk) {
          _pendingChunk.add(val.clamp(0, 255).toDouble() / 255.0);
        }
        _schedulePendingFlush();
      }
    });
  }

  @override
  void didUpdateWidget(LiveECGGraphWidget old) {
    super.didUpdateWidget(old);
    
    // Handle connections/disconnections
    if (widget.isConnected && !old.isConnected) {
      setState(() {
        _samples.clear();
        _samples.addAll(widget.ecgData.map((val) => val.clamp(0, 255).toDouble() / 255.0));
        _scrollOffset = _samples.length * _pixelsPerSample;
      });
    } else if (!widget.isConnected && old.isConnected) {
      setState(() {
        _samples.clear();
        _scrollOffset = 0;
      });
    }
  }

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  // Premium classic pink ECG paper color schema for light mode
  // Sleek crimson glowing ECG grid on a dark theme background for dark mode
  Color get _bgColor =>
      _isDark ? const Color(0xFF0F0000) : const Color(0xFFFFF2F2);

  Color get _lineColor =>
      _isDark ? const Color(0xFF00FF41) : const Color(0xFF1E1E1E);

  Color get _gridMajor => _isDark
      ? const Color(0xFFFF3333).withValues(alpha: 0.35)
      : const Color(0xFFFF9494).withValues(alpha: 0.80);

  Color get _gridMinor => _isDark
      ? const Color(0xFFFF3333).withValues(alpha: 0.15)
      : const Color(0xFFFFD1D1).withValues(alpha: 0.55);

  double _graphHeight(BuildContext context) {
    final mq = MediaQuery.of(context);
    if (widget.isFullscreen) {
      return mq.size.height - mq.padding.top - mq.padding.bottom - 120;
    }
    if (mq.orientation == Orientation.landscape) {
      return mq.size.height * 0.52;
    }
    return (mq.size.height * 0.30).clamp(160.0, 270.0);
  }

  @override
  void dispose() {
    _blinkController.dispose();
    _ecgSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isConnected) return _buildDisabledState(context);
    if (widget.hasError) return _buildErrorState(context);
    return _buildGraph(context);
  }

  Widget _buildDisabledState(BuildContext context) {
    return Container(
      width: double.infinity,
      height: _graphHeight(context),
      decoration: BoxDecoration(
        color: _isDark ? const Color(0xFF0D0D0D) : Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isDark
              ? AppColors.darkBorder
              : Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bluetooth_disabled,
              size: 52,
              color: _isDark ? Colors.grey[700] : Colors.grey[400]),
          const SizedBox(height: 14),
          Text(
            'No Device Connected',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: _isDark ? Colors.grey[400] : Colors.grey[700]),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Connect a Bluetooth device to view live ECG',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _isDark ? Colors.grey[600] : Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: widget.onConnectDevice,
            icon: const Icon(Icons.bluetooth_searching, size: 18),
            label: const Text('Connect Device'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    final errorColor = _isDark ? Colors.red[400]! : Colors.red[700]!;
    return Container(
      width: double.infinity,
      height: _graphHeight(context),
      decoration: BoxDecoration(
        color: _isDark
            ? Colors.red[900]!.withValues(alpha: 0.15)
            : Colors.red[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: errorColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 52, color: errorColor),
          const SizedBox(height: 14),
          Text(
            'Signal Error',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold, color: errorColor),
          ),
          if (widget.errorMessage != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                widget.errorMessage!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _isDark ? Colors.red[300] : Colors.red[600]),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: widget.onConnectDevice,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Reconnect'),
            style: ElevatedButton.styleFrom(backgroundColor: errorColor),
          ),
        ],
      ),
    );
  }

  Widget _buildGraph(BuildContext context) {
    final mq = MediaQuery.of(context);
    final isLandscape = mq.orientation == Orientation.landscape;
    final graphH = _graphHeight(context);

    return Container(
      decoration: BoxDecoration(
        color: _isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isDark
              ? AppColors.darkBorder
              : Colors.grey.withValues(alpha: 0.15),
        ),
        boxShadow: _isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
                14, isLandscape ? 7 : 12, 8, isLandscape ? 5 : 8),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: (_isDark
                            ? const Color(0xFF00FF41)
                            : AppColors.primary)
                        .withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.monitor_heart_outlined,
                    size: 17,
                    color: _isDark
                        ? const Color(0xFF00FF41)
                        : AppColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Live ECG',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        ' samples',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                              fontSize: 9.5,
                              color: _isDark
                                  ? AppColors.darkTextMuted
                                  : Colors.grey[500],
                            ),
                      ),
                    ],
                  ),
                ),
                AnimatedBuilder(
                  animation: _blinkController,
                  builder: (context, child) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(
                          alpha: 0.10 + 0.10 * _blinkController.value),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(
                                alpha: 0.45 +
                                    0.55 * _blinkController.value),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'LIVE',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.success,
                            letterSpacing: 0.7,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                if (widget.onFullscreen != null && !widget.isFullscreen)
                  IconButton(
                    onPressed: widget.onFullscreen,
                    icon: const Icon(Icons.open_in_full, size: 18),
                    tooltip: 'Fullscreen',
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(6),
                  )
                else if (widget.isFullscreen)
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_fullscreen, size: 18),
                    tooltip: 'Exit fullscreen',
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(6),
                  ),
              ],
            ),
          ),
          ClipRRect(
            child: SizedBox(
              width: double.infinity,
              height: graphH,
              child: CustomPaint(
                painter: ECGPainter(
                  samples: List.unmodifiable(_samples),
                  scrollOffset: _scrollOffset,
                  lineColor: _lineColor,
                  gridMajorColor: _gridMajor,
                  gridMinorColor: _gridMinor,
                  bgColor: _bgColor,
                  pixelsPerSample: _pixelsPerSample,
                ),
              ),
            ),
          ),
          _buildTimeAxis(context, isLandscape),
        ],
      ),
    );
  }

  Widget _buildTimeAxis(BuildContext context, bool isLandscape) {
    const labelIntervalPx = 50.0;
    const samplesPerSecond = 250.0;

    return Container(
      height: isLandscape ? 22 : 26,
      decoration: BoxDecoration(
        color: _isDark ? AppColors.darkSurface2 : Colors.grey[100],
        borderRadius:
            const BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: LayoutBuilder(builder: (ctx, constraints) {
        final w = constraints.maxWidth;
        final count = (w / labelIntervalPx).ceil() + 2;
        final rightTimeSec = _samples.length / samplesPerSecond;
        return Stack(
          children: [
            for (int i = 0; i < count; i++) ...[
              Positioned(
                left: (i * labelIntervalPx -
                        (_scrollOffset % labelIntervalPx))
                    .clamp(-labelIntervalPx, w + labelIntervalPx),
                top: 4,
                child: Builder(builder: (_) {
                  final samplesPerLabel =
                      labelIntervalPx / _pixelsPerSample;
                  final samplesFromRight =
                      _samples.length - i * samplesPerLabel;
                  final labelSec =
                      rightTimeSec - samplesFromRight / samplesPerSecond;
                  if (labelSec < 0) return const SizedBox.shrink();
                  return Text(
                    's',
                    style: TextStyle(
                      fontSize: 8.5,
                      color: _isDark
                          ? AppColors.darkTextMuted
                          : Colors.grey[500],
                    ),
                  );
                }),
              ),
              Positioned(
                left: (i * labelIntervalPx -
                        (_scrollOffset % labelIntervalPx))
                    .clamp(-labelIntervalPx, w + labelIntervalPx),
                top: 0,
                child: Container(
                  width: 1,
                  height: 5,
                  color: _isDark
                      ? AppColors.darkBorder
                      : Colors.grey.withValues(alpha: 0.3),
                ),
              ),
            ],
          ],
        );
      }),
    );
  }
}

// FullscreenECGGraph
class FullscreenECGGraph extends StatelessWidget {
  final List<int>? ecgData;
  final bool? isConnected;
  final bool? hasError;
  final String? errorMessage;

  const FullscreenECGGraph({
    super.key,
    this.ecgData,
    this.isConnected,
    this.hasError,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkBg
          : Colors.white,
      appBar: AppBar(
        title: const Text('Live ECG - Fullscreen'),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
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
      ),
    );
  }
}
