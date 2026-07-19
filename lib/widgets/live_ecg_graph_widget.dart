import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'dart:async';
import 'dart:io' show Platform;
import '../constants/app_theme.dart';
import '../providers/index.dart';
import '../utils/service_locator.dart';

// ── Constants – match the Python BLE receiver ─────────────────────────────────
/// Visible sample window: matches Python `deque(maxlen=750)` → 3 s @ 250 Hz.
const int _kDisplayWindow = 750;

// ── ECGPainter ────────────────────────────────────────────────────────────────
class ECGPainter extends CustomPainter {
  /// Full normalised sample buffer; the painter renders only the last
  /// [displayWindow] entries, mirroring Python's fixed-width scrolling plot.
  final List<double> samples;

  /// Absolute buffer indices where a BLE packet gap was detected.
  /// Each entry will be drawn as a red vertical bar with a '▲GAP' label.
  final List<int> gapSampleIndices;

  final Color lineColor;
  final Color gridMajorColor;
  final Color gridMinorColor;
  final Color bgColor;

  /// Samples shown at once – default matches Python `deque(maxlen=750)`.
  final int displayWindow;

  const ECGPainter({
    required this.samples,
    required this.gapSampleIndices,
    required this.lineColor,
    required this.gridMajorColor,
    required this.gridMinorColor,
    required this.bgColor,
    this.displayWindow = _kDisplayWindow,
  });

  /// Dynamic: 750 samples always span the full canvas width – no fixed constant.
  double _pxPS(double canvasWidth) => canvasWidth / displayWindow;

  double _normalize(double val, double minY, double maxY) {
    final range = maxY - minY;
    if (range < 1e-6) return 0.5;
    return (val - minY) / range;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Calculate dynamic symmetric min/max around 0
    double maxAbs = 200.0;
    if (samples.isNotEmpty) {
      final startIdx = math.max(0, samples.length - displayWindow);
      for (int i = startIdx; i < samples.length; i++) {
        final absVal = samples[i].abs();
        if (absVal > maxAbs) {
          maxAbs = absVal;
        }
      }
    }
    maxAbs = maxAbs * 1.15; // 15% padding
    final minY = -maxAbs;
    final maxY = maxAbs;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = bgColor,
    );
    _drawGrid(canvas, size);
    _drawBaseline(canvas, size, minY, maxY);
    _drawYAxisLabels(canvas, size, minY, maxY);
    _drawWaveform(canvas, size, minY, maxY);
    _drawGapMarkers(canvas, size);
    _drawTimeLabels(canvas, size);
  }

  // ── Grid ───────────────────────────────────────────────────────────────────
  void _drawGrid(Canvas canvas, Size size) {
    final minorPaint = Paint()
      ..color = gridMinorColor
      ..strokeWidth = 0.5;
    final majorPaint = Paint()
      ..color = gridMajorColor
      ..strokeWidth = 1.0;
    const smallPx = 10.0;
    const bigPx = 50.0;

    for (double x = 0; x <= size.width; x += smallPx) {
      final isMajor = (x % bigPx) < 0.6;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height),
          isMajor ? majorPaint : minorPaint);
    }
    for (double y = 0; y <= size.height; y += smallPx) {
      final isMajor = (y % bigPx) < 0.6;
      canvas.drawLine(Offset(0, y), Offset(size.width, y),
          isMajor ? majorPaint : minorPaint);
    }
  }

  // ── ADC = 0 horizontal baseline (resting potential reference) ──────────────
  void _drawBaseline(Canvas canvas, Size size, double minY, double maxY) {
    final y = size.height * (1.0 - _normalize(0, minY, maxY));
    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      Paint()
        ..color = gridMajorColor.withValues(alpha: 0.60)
        ..strokeWidth = 1.0,
    );
  }

  // ── Y-axis: raw ADC count labels on left margin ────────────────────────────
  void _drawYAxisLabels(Canvas canvas, Size size, double minY, double maxY) {
    final adcLabels = <double>[minY, minY / 2, 0, maxY / 2, maxY];
    for (final adcVal in adcLabels) {
      final y = size.height * (1.0 - _normalize(adcVal, minY, maxY));
      final tp = TextPainter(
        text: TextSpan(
          text: '${adcVal.round()}',
          style: TextStyle(
            color: gridMajorColor.withValues(alpha: 0.85),
            fontSize: 8.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final labelY =
          (y - tp.height / 2).clamp(0.0, size.height - tp.height);
      tp.paint(canvas, Offset(2.0, labelY));
    }
  }

  // ── Time labels at dynamic sample rate ──────────────────────────────────────
  void _drawTimeLabels(Canvas canvas, Size size) {
    if (samples.isEmpty) return;
    final pxPS = _pxPS(size.width);
    final startIdx = math.max(0, samples.length - displayWindow);
    final fs = bluetoothService.actualSampleRate;
    final startSec = (startIdx / fs).floor();
    final endSec = ((samples.length - 1) / fs).ceil();

    final textStyle = TextStyle(
      color: gridMajorColor.withValues(alpha: 0.85),
      fontSize: 9.0,
      fontWeight: FontWeight.w600,
    );

    for (int s = startSec; s <= endSec; s++) {
      final sampleIdx = (s * fs).round();
      if (sampleIdx < startIdx || sampleIdx >= samples.length) continue;
      final x = (sampleIdx - startIdx) * pxPS;
      if (x < 0 || x > size.width) continue;

      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        Paint()
          ..color = gridMajorColor.withValues(alpha: 0.22)
          ..strokeWidth = 0.8,
      );
      final tp = TextPainter(
        text: TextSpan(text: '${s}s', style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x + 3, size.height - 14));
    }
  }

  // ── Waveform: last [displayWindow] samples, newest pinned to right ─────────
  void _drawWaveform(Canvas canvas, Size size, double minY, double maxY) {
    if (samples.isEmpty) return;
    final pxPS = _pxPS(size.width);
    final startIdx = math.max(0, samples.length - displayWindow);

    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    bool started = false;

    for (int i = startIdx; i < samples.length; i++) {
      final x = (i - startIdx) * pxPS;
      final y = size.height * (1.0 - _normalize(samples[i], minY, maxY));
      if (!started) {
        path.moveTo(x, y);
        started = true;
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);

    // Write-head cursor at the right edge (only when buffer is full)
    if (started && samples.length >= displayWindow) {
      canvas.drawLine(
        Offset(size.width, 0),
        Offset(size.width, size.height),
        Paint()
          ..color = lineColor.withValues(alpha: 0.25)
          ..strokeWidth = 1.2,
      );
    }
  }

  // ── Gap markers: red vertical bars for detected BLE packet loss ────────────
  void _drawGapMarkers(Canvas canvas, Size size) {
    if (gapSampleIndices.isEmpty) return;
    final pxPS = _pxPS(size.width);
    final startIdx = math.max(0, samples.length - displayWindow);

    final gapPaint = Paint()
      ..color = Colors.redAccent.withValues(alpha: 0.65)
      ..strokeWidth = 1.5;

    for (final gapIdx in gapSampleIndices) {
      if (gapIdx < startIdx || gapIdx >= samples.length) continue;
      final x = (gapIdx - startIdx) * pxPS;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gapPaint);

      final tp = TextPainter(
        text: const TextSpan(
          text: '▲GAP',
          style: TextStyle(
            color: Colors.redAccent,
            fontSize: 7.5,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x + 2, 4));
    }
  }

  @override
  bool shouldRepaint(ECGPainter old) => true;
}

// ── LiveECGGraphWidget ────────────────────────────────────────────────────────
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
  /// Raw sample buffer. Painter shows only the last [_kDisplayWindow] entries.
  final List<double> _samples = [];

  /// Absolute buffer indices where BLE packet gaps were detected.
  final List<int> _gapSampleIndices = [];

  /// Internal ring capacity – ~20 s of history at 250 Hz.
  static const int _maxSamples = 5000;

  late AnimationController _blinkController;
  StreamSubscription<List<int>>? _ecgSubscription;
  StreamSubscription<int>? _gapSubscription;

  // ── Lock-free double buffer for thread-safe BLE → UI transfer ─────────────
  // BLE callbacks arrive on arbitrary Dart isolate micro-tasks. We accumulate
  // them here and drain them on a guaranteed 16ms Timer so the graph always
  // repaints even when the widget is otherwise idle (no animation frames).
  final List<double> _pendingChunk = [];
  Timer? _renderTimer;

  // ── DC-bias removal (IIR high-pass filter) ────────────────────────────────
  // Real ECG ADC chips (AD8232 etc.) output values centred around mid-rail
  // (~512 for 10-bit, ~2048 for 12-bit). We subtract a slow-moving mean so
  // that actual device data is centred at 0, just like the simulator waveform.
  // α ≈ 1 − 1/(fs·τ) where τ = 2 s, fs = 250 Hz → α ≈ 0.998
  static const double _dcAlpha = 0.998;
  double _dcEstimate = 0.0;   // tracks the DC level
  bool _dcInitialised = false;

  /// Remove DC offset from a raw ADC sample.
  /// Skips filtering for the simulator whose waveform is already AC-coupled.
  double _removeDC(double raw) {
    if (bluetoothService.isSimulatorDevice) return raw;
    if (!_dcInitialised) {
      _dcEstimate = raw;
      _dcInitialised = true;
      return 0.0;
    }
    _dcEstimate = _dcAlpha * _dcEstimate + (1.0 - _dcAlpha) * raw;
    return raw - _dcEstimate;
  }

  /// Drain the pending chunk into the main buffer and trigger a repaint.
  /// Called by the 60 Hz Timer — fires regardless of whether Flutter has
  /// an animation frame queued, fixing the "idle widget freezes" bug.
  void _flushPending() {
    if (!mounted || _pendingChunk.isEmpty) return;
    setState(() {
      _samples.addAll(_pendingChunk);
      _pendingChunk.clear();
      if (_samples.length > _maxSamples) {
        final removeCount = _samples.length - _maxSamples;
        _samples.removeRange(0, removeCount);

        // Correctly shift and trim gap markers to match shifted _samples buffer.
        // Prevents _gapSampleIndices from growing indefinitely and freezing UI thread.
        final updatedGaps = <int>[];
        for (final idx in _gapSampleIndices) {
          final newIdx = idx - removeCount;
          if (newIdx >= 0) {
            updatedGaps.add(newIdx);
          }
        }
        _gapSampleIndices.clear();
        _gapSampleIndices.addAll(updatedGaps);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      _blinkController.repeat(reverse: true);
    }

    // Warm-up from existing provider buffer (seed with any buffered samples)
    _samples.addAll(widget.ecgData.map((v) => _removeDC(v.toDouble())));

    // ── 60 Hz render-flush timer ─────────────────────────────────────────────
    // This guarantees the graph repaints every ~16 ms even when nothing else
    // is triggering Flutter frame scheduling. This is the primary fix for
    // the "real device shows gaps" bug.
    _renderTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      _flushPending();
    });

    // Subscribe to the BLE ECG sample stream
    _ecgSubscription = bluetoothService.ecgDataStream.listen((chunk) {
      if (mounted && widget.isConnected && !widget.hasError) {
        for (final v in chunk) {
          // Apply DC removal here, on the receiving side, before buffering
          _pendingChunk.add(_removeDC(v.toDouble()));
        }
        // No longer call _schedulePendingFlush() — the timer handles it
      }
    });

    // Subscribe to gap events – record the position in the sample buffer
    _gapSubscription = bluetoothService.gapEventStream.listen((_) {
      if (mounted && widget.isConnected) {
        final pos = _samples.length + _pendingChunk.length;
        // Use microtask to avoid calling setState from within stream listener
        Future.microtask(() {
          if (mounted) {
            setState(() {
              _gapSampleIndices.add(pos);
            });
          }
        });
      }
    });
  }

  @override
  void didUpdateWidget(LiveECGGraphWidget old) {
    super.didUpdateWidget(old);

    if (widget.isConnected && !old.isConnected) {
      // Reset DC filter state when a new device connects
      _dcInitialised = false;
      _dcEstimate = 0.0;
      setState(() {
        _samples.clear();
        _pendingChunk.clear();
        _gapSampleIndices.clear();
        _samples.addAll(
            widget.ecgData.map((v) => _removeDC(v.toDouble())));
      });
    } else if (!widget.isConnected && old.isConnected) {
      setState(() {
        _samples.clear();
        _pendingChunk.clear();
        _gapSampleIndices.clear();
      });
    }
  }

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get _bgColor =>
      _isDark ? const Color(0xFF1C1C1E) : Colors.white;

  Color get _lineColor => const Color(0xFFE82D4F); // Classic ECG Crimson Red

  Color get _gridMajor =>
      _isDark ? const Color(0xFF3F3F42) : const Color(0xFFD0D0D2);

  Color get _gridMinor =>
      _isDark ? const Color(0xFF2C2C2E) : const Color(0xFFEBEBEB);

  double _graphHeight(BuildContext context) {
    final mq = MediaQuery.of(context);
    if (widget.isFullscreen) return double.infinity;
    if (mq.orientation == Orientation.landscape) {
      return mq.size.height * 0.52;
    }
    return (mq.size.height * 0.30).clamp(160.0, 270.0);
  }

  @override
  void dispose() {
    _renderTimer?.cancel();
    _renderTimer = null;
    _blinkController.dispose();
    _ecgSubscription?.cancel();
    _gapSubscription?.cancel();
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
    final graphH = _graphHeight(context);
    return Container(
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _gridMajor, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: GestureDetector(
          onTap: widget.onFullscreen,
          child: Stack(
            children: [
              SizedBox(
                width: double.infinity,
                height: widget.isFullscreen ? double.infinity : graphH,
                child: CustomPaint(
                  painter: ECGPainter(
                    samples: List.unmodifiable(_samples),
                    gapSampleIndices:
                        List.unmodifiable(_gapSampleIndices),
                    lineColor: _lineColor,
                    gridMajorColor: _gridMajor,
                    gridMinorColor: _gridMinor,
                    bgColor: _bgColor,
                  ),
                ),
              ),
              if (widget.onFullscreen != null && !widget.isFullscreen)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: (_isDark ? Colors.black : Colors.white)
                          .withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.open_in_full,
                        color: _isDark ? Colors.white : Colors.black87,
                        size: 18,
                      ),
                      onPressed: widget.onFullscreen,
                      tooltip: 'Fullscreen',
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── FullscreenECGGraph ────────────────────────────────────────────────────────
class FullscreenECGGraph extends StatefulWidget {
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
  State<FullscreenECGGraph> createState() => _FullscreenECGGraphState();
}

class _FullscreenECGGraphState extends State<FullscreenECGGraph> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor =
        isDark ? const Color(0xFF00BFA5) : const Color(0xFF008B7A);
    final bgColor = isDark ? const Color(0xFF121212) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Consumer2<BluetoothProvider, ECGProvider>(
          builder: (context, btProvider, ecgProvider, _) {
            final isConnected = btProvider.isConnected;
            final hasError = ecgProvider.hasDataError;
            final signalText = isConnected
                ? (hasError ? 'Poor Signal' : 'Great Signal')
                : 'No Signal';
            final heartRateStr =
                isConnected && btProvider.currentHeartRate > 0
                    ? '${btProvider.currentHeartRate}'
                    : '--';

            return Column(
              children: [
                // ── App Bar ──────────────────────────────────────────────────
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_ios_new,
                            color: accentColor, size: 20),
                        onPressed: () => Navigator.pop(context),
                        tooltip: 'Back',
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.monitor_heart,
                              color: accentColor, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'Live ECG Analysis Terminal',
                            style: TextStyle(
                              color:
                                  isDark ? Colors.white : Colors.black87,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00C853)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFF00C853)
                                  .withValues(alpha: 0.35)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _LiveStatusDot(),
                            SizedBox(width: 6),
                            Text(
                              'LIVE',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF00C853),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Metrics Row ──────────────────────────────────────────────
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      // Signal quality
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.signal_cellular_alt,
                            color: isConnected && !hasError
                                ? accentColor
                                : Colors.grey,
                            size: 26,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            signalText,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isConnected && !hasError
                                  ? (isDark
                                      ? Colors.grey[300]
                                      : Colors.grey[700])
                                  : Colors.grey,
                            ),
                          ),
                        ],
                      ),

                      // AI inference status
                      Consumer<ECGProvider>(
                        builder: (context, ecgProv, _) {
                          final result = ecgProv.latestInferenceResult;
                          String statusText = '--';
                          Color statusColor = Colors.grey;

                          if (isConnected) {
                            if (result == null) {
                              statusText = '--';
                              statusColor = Colors.grey;
                            } else if (result.isError) {
                              statusText = 'ERR';
                              statusColor = Colors.red;
                            } else {
                              final label = result.label;
                              final isAbnormal = result.isAbnormal;
                              if (!isAbnormal || label == 'NORM') {
                                statusText = 'NORM';
                                statusColor = Colors.green[600]!;
                              } else if (label == 'MI') {
                                statusText = 'MI';
                                statusColor = Colors.red[700]!;
                              } else if (label == 'STTC') {
                                statusText = 'STTC';
                                statusColor = Colors.orange[700]!;
                              } else if (label == 'CD') {
                                statusText = 'CD';
                                statusColor = Colors.purple[600]!;
                              } else if (label == 'HYP') {
                                statusText = 'HYP';
                                statusColor = Colors.indigo[600]!;
                              } else {
                                statusText = label.toUpperCase();
                                statusColor = isAbnormal
                                    ? Colors.orange[700]!
                                    : Colors.green[600]!;
                              }
                            }
                          } else {
                            statusText = 'OFFLINE';
                            statusColor = Colors.grey[600]!;
                          }

                          return Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: statusColor,
                              letterSpacing: 0.5,
                            ),
                          );
                        },
                      ),

                      // Heart rate
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.favorite,
                              color: Colors.red, size: 26),
                          const SizedBox(height: 3),
                          Text(
                            '$heartRateStr BPM',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isConnected && !hasError
                                  ? (isDark
                                      ? Colors.grey[300]
                                      : Colors.grey[700])
                                  : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Main ECG Graph ───────────────────────────────────────────
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    child: LiveECGGraphWidget(
                      ecgData: ecgProvider.ecgData,
                      isConnected: btProvider.isConnected,
                      hasError: ecgProvider.hasDataError,
                      errorMessage: ecgProvider.errorMessage,
                      isFullscreen: true,
                    ),
                  ),
                ),

                // ── Bottom label ─────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.insights, color: accentColor, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Live ECG Analysis',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.black87,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── Supporting widgets ────────────────────────────────────────────────────────
class _PulsingStatusCircle extends StatefulWidget {
  final String statusText;
  final Color color;
  final bool isAbnormal;

  const _PulsingStatusCircle({
    required this.statusText,
    required this.color,
    required this.isAbnormal,
  });

  @override
  State<_PulsingStatusCircle> createState() => _PulsingStatusCircleState();
}

class _PulsingStatusCircleState extends State<_PulsingStatusCircle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 58 + (_controller.value * 12),
              height: 58 + (_controller.value * 12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color
                    .withValues(alpha: 0.04 + (_controller.value * 0.08)),
                border: Border.all(
                  color: widget.color
                      .withValues(alpha: 0.1 + (_controller.value * 0.2)),
                  width: 1.5,
                ),
              ),
            ),
            Container(
              width: 50 + (_controller.value * 6),
              height: 50 + (_controller.value * 6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color
                    .withValues(alpha: 0.08 + (_controller.value * 0.08)),
                border: Border.all(
                  color: widget.color
                      .withValues(alpha: 0.2 + (_controller.value * 0.3)),
                  width: 1,
                ),
              ),
            ),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withValues(alpha: 0.18),
                border: Border.all(color: widget.color, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.25),
                    blurRadius: 4.0,
                    spreadRadius: 1.0,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  widget.statusText,
                  style: TextStyle(
                    fontSize: widget.statusText.length > 5 ? 7.5 : 9.5,
                    fontWeight: FontWeight.w900,
                    color: widget.color,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LiveStatusDot extends StatefulWidget {
  const _LiveStatusDot();

  @override
  State<_LiveStatusDot> createState() => _LiveStatusDotState();
}

class _LiveStatusDotState extends State<_LiveStatusDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF00C853)
                .withValues(alpha: 0.3 + (_controller.value * 0.7)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00C853)
                    .withValues(alpha: 0.2 + (_controller.value * 0.5)),
                blurRadius: 3.0 + (_controller.value * 5.0),
                spreadRadius: 0.5 + (_controller.value * 1.5),
              ),
            ],
          ),
        );
      },
    );
  }
}
