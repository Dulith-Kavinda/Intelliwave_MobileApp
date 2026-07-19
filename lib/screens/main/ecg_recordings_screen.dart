import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import '../../constants/app_theme.dart';
import '../../models/ecg_recording_model.dart';
import '../../models/ecg_inference_result.dart';
import '../../utils/service_locator.dart';

// ── Static ECG Painter — identical visual language to LiveECGGraph ─────────────
/// Renders a static recorded ECG waveform using the same medical-paper grid,
/// crimson red line, Y-axis ADC labels, and time labels as [ECGPainter].
class _RecordedECGPainter extends CustomPainter {
  final List<double> samples;
  final double sampleRate; // Hz — used for time-axis labels
  final Color lineColor;
  final Color gridMajorColor;
  final Color gridMinorColor;
  final Color bgColor;
  /// Horizontal offset in samples (for horizontal scroll).
  final int startSampleIdx;
  /// How many samples to display across the canvas width.
  final int displayWindow;

  const _RecordedECGPainter({
    required this.samples,
    required this.sampleRate,
    required this.lineColor,
    required this.gridMajorColor,
    required this.gridMinorColor,
    required this.bgColor,
    required this.startSampleIdx,
    required this.displayWindow,
  });

  double _normalize(double val, double minY, double maxY) {
    final range = maxY - minY;
    if (range < 1e-6) return 0.5;
    return (val - minY) / range;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // ── Dynamic Y range (symmetric around 0) ──────────────────────────────────
    double maxAbs = 200.0;
    for (final v in samples) {
      final a = v.abs();
      if (a > maxAbs) maxAbs = a;
    }
    maxAbs *= 1.15;
    final minY = -maxAbs;
    final maxY = maxAbs;

    // Background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = bgColor,
    );

    _drawGrid(canvas, size);
    _drawBaseline(canvas, size, minY, maxY);
    _drawYAxisLabels(canvas, size, minY, maxY);
    _drawWaveform(canvas, size, minY, maxY);
    _drawTimeLabels(canvas, size);
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
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(canvas,
          Offset(2.0, (y - tp.height / 2).clamp(0.0, size.height - tp.height)));
    }
  }

  void _drawTimeLabels(Canvas canvas, Size size) {
    if (samples.isEmpty) return;
    final visibleEnd =
        math.min(startSampleIdx + displayWindow, samples.length);
    final pxPS = size.width / displayWindow;
    final startSec = (startSampleIdx / sampleRate).floor();
    final endSec = ((visibleEnd - 1) / sampleRate).ceil();

    final textStyle = TextStyle(
      color: gridMajorColor.withValues(alpha: 0.85),
      fontSize: 9.0,
      fontWeight: FontWeight.w600,
    );

    for (int s = startSec; s <= endSec; s++) {
      final sampleIdx = (s * sampleRate).round();
      if (sampleIdx < startSampleIdx || sampleIdx >= visibleEnd) continue;
      final x = (sampleIdx - startSampleIdx) * pxPS;
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
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x + 3, size.height - 14));
    }
  }

  void _drawWaveform(Canvas canvas, Size size, double minY, double maxY) {
    if (samples.isEmpty) return;
    final pxPS = size.width / displayWindow;
    final endIdx = math.min(startSampleIdx + displayWindow, samples.length);

    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    bool started = false;
    for (int i = startSampleIdx; i < endIdx; i++) {
      final x = (i - startSampleIdx) * pxPS;
      final y = size.height * (1.0 - _normalize(samples[i], minY, maxY));
      if (!started) {
        path.moveTo(x, y);
        started = true;
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_RecordedECGPainter old) => true;
}

class ECGRecordingsScreen extends StatefulWidget {
  final List<ECGRecording>? initialRecordings;
  final bool showAppBar;

  const ECGRecordingsScreen({
    Key? key,
    this.initialRecordings,
    this.showAppBar = true,
  }) : super(key: key);

  @override
  State<ECGRecordingsScreen> createState() => _ECGRecordingsScreenState();
}

class _ECGRecordingsScreenState extends State<ECGRecordingsScreen> {
  late List<ECGRecording> _allRecordings;
  late List<ECGRecording> _filteredRecordings;
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    _allRecordings = widget.initialRecordings ?? storageService.getECGRecordings();
    _filteredRecordings = List.from(_allRecordings);
  }

  // Per-recording loading state — keyed by recording.id.
  final Map<String, ValueNotifier<bool>> _analyzingStates = {};

  ValueNotifier<bool> _analyzeState(String id) =>
      _analyzingStates.putIfAbsent(id, () => ValueNotifier(false));

  @override
  void dispose() {
    for (final n in _analyzingStates.values) {
      n.dispose();
    }
    super.dispose();
  }

  void _applyDateFilter() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
        _filterRecordings();
      });
    }
  }

  void _filterRecordings() {
    if (_selectedDateRange == null) {
      _filteredRecordings = List.from(_allRecordings);
      return;
    }

    _filteredRecordings = _allRecordings.where((recording) {
      return recording.recordedAt.isAfter(_selectedDateRange!.start) &&
          recording.recordedAt.isBefore(
            _selectedDateRange!.end.add(const Duration(days: 1)),
          );
    }).toList();
  }

  void _clearDateFilter() {
    setState(() {
      _selectedDateRange = null;
      _filteredRecordings = List.from(_allRecordings);
    });
  }

  Future<void> _exportAsPdf(BuildContext context, ECGRecording recording) async {
    try {
      final pdf = pw.Document();

      // Load logo image
      final logoData = await rootBundle.load('assets/images/app_logo.png');
      final logoImage = pw.MemoryImage(logoData.buffer.asUint8List());

      final rawEcgData = recording.ecgData;
      final double sum = rawEcgData.isNotEmpty
          ? rawEcgData.reduce((a, b) => a + b)
          : 0.0;
      final double mean = rawEcgData.isNotEmpty ? sum / rawEcgData.length : 0.0;
      final List<double> ecgData = rawEcgData.map((v) => v - mean).toList();

      final double frequency = recording.durationSeconds > 0
          ? ecgData.length / recording.durationSeconds
          : 250.0;

      // Standard medical ECG scale: 25 mm/s speed (1 mm = 1 small square)
      final double mmPx = PdfPageFormat.mm; // ~2.83465 points/mm
      final double pxPerSec = 25.0 * mmPx; // ~70.866 points/sec
      final double canvasWidth = 530.0;
      final int pointsPerRow = math.max(1, ((canvasWidth / pxPerSec) * frequency).floor());
      final int numRows = (ecgData.length / pointsPerRow).ceil();
      final List<List<double>> rowsData = [];
      for (int i = 0; i < numRows; i++) {
        final start = i * pointsPerRow;
        final end = (start + pointsPerRow < ecgData.length) ? start + pointsPerRow : ecgData.length;
        rowsData.add(ecgData.sublist(start, end));
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            final widgets = <pw.Widget>[];

            // 1. Header Section
            widgets.add(
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Row(
                    children: [
                      pw.Image(logoImage, width: 32, height: 32),
                      pw.SizedBox(width: 8),
                      pw.Text(
                        'IntelIWave ECG Report',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.indigo,
                        ),
                      ),
                    ],
                  ),
                  pw.Text(
                    DateFormat('dd/MM/yyyy HH:mm').format(recording.recordedAt),
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                ],
              ),
            );
            widgets.add(pw.Divider(color: PdfColors.grey300, thickness: 1));
            widgets.add(pw.SizedBox(height: 10));

            // 2. Patient & Device Information
            widgets.add(pw.Text('Device: ${recording.deviceName}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)));
            widgets.add(pw.Text('Recording ID: ${recording.id}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)));
            widgets.add(pw.SizedBox(height: 12));

            // 3. Metrics Table
            widgets.add(
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                headers: ['Metric', 'Value'],
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                cellStyle: const pw.TextStyle(fontSize: 9),
                data: [
                  ['Duration', recording.getFormattedDuration()],
                  ['Average Heart Rate', '${recording.getHeartRate()} bpm'],
                  ['Paper Speed / Scale', '25 mm/s (1 mm = 0.04s)'],
                  ['Signal Quality', recording.healthMetrics['quality'] ?? 'N/A'],
                ],
              ),
            );
            widgets.add(pw.SizedBox(height: 15));

            // 4. Waveform Title
            widgets.add(pw.Text('Recorded ECG Waveform (Standard 25 mm/s Scale)', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)));
            widgets.add(pw.SizedBox(height: 8));

            // 5. Render rows of waveform with 25 mm/s RED GRID (1 mm small square)
            if (rowsData.isEmpty) {
              widgets.add(
                pw.Container(
                  height: 60,
                  alignment: pw.Alignment.center,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                  ),
                  child: pw.Text('No ECG data points recorded', style: const pw.TextStyle(color: PdfColors.grey)),
                ),
              );
            } else {
              // Pre-compute global Y range once so all strips share the same scale
              double globalMaxAbs = 200.0;
              for (final v in ecgData) {
                final a = v.abs();
                if (a > globalMaxAbs) globalMaxAbs = a;
              }
              globalMaxAbs *= 1.15;
              final globalMinY = -globalMaxAbs;
              final globalMaxY = globalMaxAbs;

              double normalizeForPdf(double val, double minY, double maxY, double canvasH) {
                // PDF canvas Y=0 is bottom, canvasH is top (norm * canvasH keeps peaks UPWARDS)
                final norm = ((val - minY) / (maxY - minY)).clamp(0.0, 1.0);
                return norm * canvasH;
              }

              for (int rowIndex = 0; rowIndex < rowsData.length; rowIndex++) {
                final rowSamples = rowsData[rowIndex];
                final double startTime = (rowIndex * pointsPerRow) / frequency;
                final double endTime =
                    ((rowIndex * pointsPerRow) + rowSamples.length) / frequency;

                widgets.add(
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 2, top: 6),
                        child: pw.Text(
                          'Strip ${rowIndex + 1} (${startTime.toStringAsFixed(1)}s - ${endTime.toStringAsFixed(1)}s)',
                          style: const pw.TextStyle(
                              fontSize: 8, color: PdfColors.grey700),
                        ),
                      ),
                      pw.Container(
                        height: 100,
                        width: 530,
                        decoration: pw.BoxDecoration(
                          color: PdfColors.white,
                          borderRadius:
                              const pw.BorderRadius.all(pw.Radius.circular(4)),
                          border: pw.Border.all(
                              color: PdfColor.fromInt(0xFFEF9A9A), width: 0.8),
                        ),
                        child: pw.CustomPaint(
                          size: const PdfPoint(530, 100),
                          painter: (PdfGraphics canvas, PdfPoint sz) {
                            // ── Minor red grid (1 mm spacing = 1 small square = 0.04s)
                            final double smallPx = 1.0 * PdfPageFormat.mm;
                            canvas.setStrokeColor(
                                PdfColor.fromInt(0xFFFFCDD2));
                            canvas.setLineWidth(0.35);
                            for (double x = 0; x <= sz.x; x += smallPx) {
                              canvas.moveTo(x, 0);
                              canvas.lineTo(x, sz.y);
                              canvas.strokePath();
                            }
                            for (double y = 0; y <= sz.y; y += smallPx) {
                              canvas.moveTo(0, y);
                              canvas.lineTo(sz.x, y);
                              canvas.strokePath();
                            }

                            // ── Major red grid (5 mm spacing = 1 large square = 0.20s)
                            final double bigPx = 5.0 * PdfPageFormat.mm;
                            canvas.setStrokeColor(
                                PdfColor.fromInt(0xFFEF9A9A));
                            canvas.setLineWidth(0.75);
                            for (double x = 0; x <= sz.x; x += bigPx) {
                              canvas.moveTo(x, 0);
                              canvas.lineTo(x, sz.y);
                              canvas.strokePath();
                            }
                            for (double y = 0; y <= sz.y; y += bigPx) {
                              canvas.moveTo(0, y);
                              canvas.lineTo(sz.x, y);
                              canvas.strokePath();
                            }

                            // ── Baseline (Y = 0) ────────────────────────────
                            final double baselineY =
                                normalizeForPdf(0, globalMinY, globalMaxY, sz.y);
                            canvas.setStrokeColor(
                                PdfColor.fromInt(0xFFE57373));
                            canvas.setLineWidth(0.9);
                            canvas.moveTo(0, baselineY);
                            canvas.lineTo(sz.x, baselineY);
                            canvas.strokePath();

                            // ── Time-axis tick marks (every 1 sec = 25 mm) ──
                            canvas.setStrokeColor(
                                PdfColor.fromInt(0xFFE57373));
                            canvas.setLineWidth(0.5);
                            final double step = pxPerSec / frequency;
                            final int startSample = rowIndex * pointsPerRow;
                            final int startSec = (startSample / frequency).floor();
                            final int endSec =
                                ((startSample + rowSamples.length - 1) / frequency)
                                    .ceil();
                            for (int s = startSec; s <= endSec; s++) {
                              final int sIdx =
                                  (s * frequency).round() - startSample;
                              if (sIdx < 0 || sIdx >= rowSamples.length) continue;
                              final double tx = sIdx * step;
                              canvas.moveTo(tx, 0);
                              canvas.lineTo(tx, sz.y);
                              canvas.strokePath();
                            }

                            // ── ECG waveform line (Dark Crimson Red) ───────────
                            if (rowSamples.isNotEmpty) {
                              canvas.setStrokeColor(
                                  PdfColor.fromInt(0xFFB71C1C));
                              canvas.setLineWidth(1.3);

                              canvas.moveTo(
                                  0,
                                  normalizeForPdf(rowSamples[0], globalMinY,
                                      globalMaxY, sz.y));
                              for (int i = 1; i < rowSamples.length; i++) {
                                canvas.lineTo(
                                    i * step,
                                    normalizeForPdf(rowSamples[i], globalMinY,
                                        globalMaxY, sz.y));
                              }
                              canvas.strokePath();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                );
              }
            }

            widgets.add(pw.SizedBox(height: 15));
            widgets.add(
              pw.Center(
                child: pw.Text(
                  'Speed: 25 mm/s | 1 small square = 1 mm (0.04s) | 1 large square = 5 mm (0.20s) | Total Data Points: ${recording.ecgData.length} samples. Generated by IntelIWave app.',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
                ),
              ),
            );

            return widgets;
          },
        ),
      );

      final output = await getTemporaryDirectory();
      final file = File('${output.path}/ecg_recording_${recording.id}.pdf');
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'My IntelIWave ECG Report from ${recording.getFormattedDate()}',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export PDF: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.initialRecordings == null) {
      _allRecordings = storageService.getECGRecordings();
      _filterRecordings();
    }
    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('ECG Recordings'),
              elevation: 0,
            )
          : null,
      body: Column(
        children: [
          // Filter Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppColors.lightGrey,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _applyDateFilter,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 18,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _selectedDateRange == null
                                      ? 'Filter by date'
                                      : '${DateFormat('dd/MM/yyyy').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM/yyyy').format(_selectedDateRange!.end)}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _selectedDateRange == null
                                        ? Colors.grey
                                        : (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppColors.darkGrey),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (_selectedDateRange != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _clearDateFilter,
                    tooltip: 'Clear filter',
                  ),
                ],
              ],
            ),
          ),
          // Results Summary
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_filteredRecordings.length} recording${_filteredRecordings.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_selectedDateRange != null)
                  Text(
                    'Filtered',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Recordings List
          Expanded(
            child: _filteredRecordings.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredRecordings.length,
                    itemBuilder: (context, index) {
                      final recording = _filteredRecordings[index];
                      return _buildRecordingCard(recording);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open,
            size: 64,
            color: AppColors.darkBorder,
          ),
          const SizedBox(height: 16),
          Text(
            _selectedDateRange == null
                ? 'No recordings yet'
                : 'No recordings found in this date range',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedDateRange == null
                ? 'Start recording to see your ECG data here'
                : 'Try adjusting the date filter',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  void _deleteRecording(ECGRecording recording) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkBg : Colors.white,
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: AppColors.danger),
            SizedBox(width: 8),
            Text('Delete Recording'),
          ],
        ),
        content: const Text('Are you sure you want to delete this recording?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await storageService.deleteECGRecording(recording.id);
              if (mounted) {
                setState(() {
                  _allRecordings.removeWhere((r) => r.id == recording.id);
                  _filterRecordings();
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Recording deleted successfully')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingCard(ECGRecording recording) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.favorite,
                  color: AppColors.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recording.deviceName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 12,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            recording.getFormattedDate(),
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    recording.getFormattedDuration(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                  onPressed: () => _deleteRecording(recording),
                  tooltip: 'Delete recording',
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Health Metrics Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetricDisplay(
                  'HR',
                  '${recording.getHeartRate()} bpm',
                  Icons.favorite_outlined,
                  Colors.red,
                ),
                _buildMetricDisplay(
                  'Quality',
                  recording.healthMetrics['quality'] ?? 'N/A',
                  Icons.signal_cellular_alt,
                  Colors.green,
                ),
              ],
            ),
            if (recording.notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Notes: ${recording.notes}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _showRecordingDetails(context, recording);
                    },
                    icon: const Icon(Icons.visibility, size: 18),
                    label: const Text('View Details'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _exportAsPdf(context, recording);
                    },
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text('Share PDF'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Analyze with AI — full-width button below the row
            ValueListenableBuilder<bool>(
              valueListenable: _analyzeState(recording.id),
              builder: (ctx, isAnalyzing, _) {
                return SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isAnalyzing
                        ? null
                        : () => _analyzeWithAI(context, recording),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: isAnalyzing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.psychology_outlined, size: 18),
                    label: Text(
                        isAnalyzing ? 'Analyzing...' : 'Analyze with AI'),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── AI Analysis ────────────────────────────────────────────────────────────

  /// Chunk the recording into 500-sample windows, run inference on each,
  /// then majority-vote the results and show a result sheet.
  Future<void> _analyzeWithAI(
    BuildContext context,
    ECGRecording recording,
  ) async {
    final stateNotifier = _analyzeState(recording.id);
    if (stateNotifier.value) return; // already running
    stateNotifier.value = true;

    try {
      final service = ecgInferenceService;

      // Model not available — show friendly error
      if (!service.isModelLoaded) {
        if (!context.mounted) return;
        _showAnalysisError(
          context,
          service.modelError ??
              'AI model is not available on this device or platform.',
        );
        return;
      }

      final samples = recording.ecgData;
      final double fs = recording.durationSeconds > 0
          ? samples.length / recording.durationSeconds
          : 250.0;
      final result = await service.runInferenceOnRecording(samples, sampleRate: fs);

      if (!context.mounted) return;

      if (result.isError) {
        _showAnalysisError(context, result.errorMessage!);
        return;
      }

      _showAnalysisResult(context, result, recording);
    } finally {
      stateNotifier.value = false;
    }
  }

  void _showAnalysisError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showAnalysisResult(
    BuildContext context,
    EcgInferenceResult result,
    ECGRecording recording,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAbnormal = result.isAbnormal;
    final resultColor = isAbnormal ? Colors.orange[700]! : Colors.green[600]!;
    final confidencePct = (result.confidence * 100).toStringAsFixed(1);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            top: 24,
            left: 24,
            right: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title
              Row(
                children: [
                  Icon(Icons.psychology_outlined,
                      color: AppColors.primary, size: 24),
                  const SizedBox(width: 10),
                  const Text(
                    'AI Analysis Result',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Result card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: resultColor.withOpacity(0.08),
                  border: Border.all(color: resultColor.withOpacity(0.4)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isAbnormal
                              ? Icons.warning_amber_rounded
                              : Icons.check_circle_outline,
                          color: resultColor,
                          size: 28,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            result.label,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: resultColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Confidence bar
                    Text(
                      'Confidence: $confidencePct%',
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: result.confidence,
                        minHeight: 8,
                        backgroundColor:
                            resultColor.withOpacity(0.15),
                        valueColor:
                            AlwaysStoppedAnimation<Color>(resultColor),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ⚠️ Medical disclaimer — mandatory, always visible
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  border: Border.all(color: Colors.amber[300]!),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline,
                        size: 18, color: Colors.amber[800]),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'This is an AI-assisted screening result, not a '
                        'medical diagnosis. Please consult a doctor for '
                        'confirmation.',
                        style: TextStyle(fontSize: 12, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricDisplay(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  void _showRecordingDetails(
    BuildContext context,
    ECGRecording recording,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.only(
            top: 24,
            left: 24,
            right: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recording Details',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow('Device', recording.deviceName),
                      _buildDetailRow('Date', recording.getFormattedDate()),
                      _buildDetailRow('Duration', recording.getFormattedDuration()),
                      _buildDetailRow(
                        'Heart Rate',
                        '${recording.getHeartRate()} BPM',
                      ),
                      _buildDetailRow(
                        'Signal Quality',
                        recording.healthMetrics['quality'] ?? 'N/A',
                      ),
                      if (recording.notes.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _buildDetailRow('Notes', recording.notes),
                      ],
                      const SizedBox(height: 20),
                      Text(
                        'ECG Waveform',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      _buildRecordedECGGraph(
                        context: context,
                        recording: recording,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 24),
                      // Analyze with AI — in detail sheet
                      ValueListenableBuilder<bool>(
                        valueListenable: _analyzeState(recording.id),
                        builder: (ctx2, isAnalyzing, _) {
                          return SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: isAnalyzing
                                  ? null
                                  : () {
                                      Navigator.pop(context);
                                      _analyzeWithAI(context, recording);
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                              ),
                              icon: isAnalyzing
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.psychology_outlined,
                                      size: 18,
                                    ),
                              label: Text(
                                isAnalyzing
                                    ? 'Analyzing...'
                                    : 'Analyze with AI',
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ── Recorded ECG graph — identical visual language to the live ECG view ─────
  /// Renders the full recording in a horizontally-scrollable ECGPainter canvas.
  /// Each "page" spans [_kWindow] samples (≈ 3 s @ 250 Hz), matching the live
  /// display window so the waveform density feels identical.
  static const int _kWindow = 750;

  Widget _buildRecordedECGGraph({
    required BuildContext context,
    required ECGRecording recording,
    required bool isDark,
  }) {
    if (recording.ecgData.isEmpty) {
      return Container(
        height: 160,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? const Color(0xFF3F3F42) : const Color(0xFFD0D0D2),
            width: 1.2,
          ),
        ),
        child: const Text(
          'No ECG data recorded',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final rawSamples = recording.ecgData;
    final double sum = rawSamples.isNotEmpty ? rawSamples.reduce((a, b) => a + b) : 0.0;
    final double mean = rawSamples.isNotEmpty ? sum / rawSamples.length : 0.0;
    final samples = rawSamples.map((v) => v - mean).toList();
    final double fs = recording.durationSeconds > 0
        ? samples.length / recording.durationSeconds
        : 250.0;

    // Total canvas width: each sample gets 1 px (same density as live graph)
    // but we clamp the minimum to fill the screen.
    final screenW = MediaQuery.of(context).size.width - 48.0;
    final totalPx = math.max(screenW, samples.length.toDouble());

    // Compute how many windows needed so the canvas covers all samples
    final int totalWindows = (samples.length / _kWindow).ceil();
    final double canvasW = totalWindows * screenW;

    final bgColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final gridMajor =
        isDark ? const Color(0xFF3F3F42) : const Color(0xFFD0D0D2);
    final gridMinor =
        isDark ? const Color(0xFF2C2C2E) : const Color(0xFFEBEBEB);

    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: gridMajor, width: 1.2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: math.max(canvasW, totalPx),
            height: 200,
            child: CustomPaint(
              painter: _RecordedECGPainter(
                samples: samples,
                sampleRate: fs,
                lineColor: const Color(0xFFE82D4F),
                gridMajorColor: gridMajor,
                gridMinorColor: gridMinor,
                bgColor: bgColor,
                startSampleIdx: 0,
                displayWindow: samples.length,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
