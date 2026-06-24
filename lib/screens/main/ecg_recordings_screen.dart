import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:share_plus/share_plus.dart';
import '../../constants/app_theme.dart';
import '../../models/ecg_recording_model.dart';
import '../../utils/service_locator.dart';

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

      final ecgData = recording.ecgData;
      final int pointsPerRow = 250;
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
                  pw.Text(
                    'IntelIWave ECG Report',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.indigo,
                    ),
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
                  ['Blood Pressure', '${recording.healthMetrics['systolic'] ?? '--'}/${recording.healthMetrics['diastolic'] ?? '--'}'],
                  ['SpO2 (Oxygen Level)', '${recording.healthMetrics['oxygen'] ?? '--'}%'],
                  ['Signal Quality', recording.healthMetrics['quality'] ?? 'N/A'],
                ],
              ),
            );
            widgets.add(pw.SizedBox(height: 15));

            // 4. Waveform Title
            widgets.add(pw.Text('Recorded ECG Waveform (Full Recording)', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)));
            widgets.add(pw.SizedBox(height: 8));

            // 5. Render rows of waveform
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
              for (int rowIndex = 0; rowIndex < rowsData.length; rowIndex++) {
                final rowSamples = rowsData[rowIndex];
                final double startTime = (rowIndex * pointsPerRow) / 200.0; // 200Hz frequency
                final double endTime = ((rowIndex * pointsPerRow) + rowSamples.length) / 200.0;

                widgets.add(
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 2, top: 6),
                        child: pw.Text(
                          'Strip ${rowIndex + 1} (${startTime.toStringAsFixed(1)}s - ${endTime.toStringAsFixed(1)}s)',
                          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                        ),
                      ),
                      pw.Container(
                        height: 90,
                        width: 530, // Fit cleanly in A4 margins
                        decoration: const pw.BoxDecoration(
                          color: PdfColor.fromInt(0xFFFFF2F2),
                        ),
                        child: pw.CustomPaint(
                          size: const PdfPoint(530, 90),
                          painter: (PdfGraphics canvas, PdfPoint size) {
                            // Draw Grid Lines
                            // Minor grid (every 5 points)
                            canvas.setStrokeColor(PdfColor.fromInt(0xFFFFD1D1));
                            canvas.setLineWidth(0.4);
                            for (double x = 0; x < size.x; x += 5) {
                              if ((x.round() % 25) != 0) {
                                canvas.moveTo(x, 0);
                                canvas.lineTo(x, size.y);
                                canvas.strokePath();
                              }
                            }
                            for (double y = 0; y < size.y; y += 5) {
                              if ((y.round() % 25) != 0) {
                                canvas.moveTo(0, y);
                                canvas.lineTo(size.x, y);
                                canvas.strokePath();
                              }
                            }

                            // Major grid (every 25 points, forming 5x5 blocks)
                            canvas.setStrokeColor(PdfColor.fromInt(0xFFFF9494));
                            canvas.setLineWidth(0.8);
                            for (double x = 0; x < size.x; x += 25) {
                              canvas.moveTo(x, 0);
                              canvas.lineTo(x, size.y);
                              canvas.strokePath();
                            }
                            for (double y = 0; y < size.y; y += 25) {
                              canvas.moveTo(0, y);
                              canvas.lineTo(size.x, y);
                              canvas.strokePath();
                            }

                            // Draw Waveform Line
                            if (rowSamples.isNotEmpty) {
                              canvas.setStrokeColor(PdfColor.fromInt(0xFF1E1E1E));
                              canvas.setLineWidth(1.0);

                              final double step = size.x / 250.0;
                              canvas.moveTo(0, (rowSamples[0] / 255.0) * size.y);
                              for (int i = 1; i < rowSamples.length; i++) {
                                final x = i * step;
                                final y = (rowSamples[i] / 255.0) * size.y;
                                canvas.lineTo(x, y);
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
                  'Total ECG Data Points: ${recording.ecgData.length} samples. This report is generated automatically by IntelIWave app.',
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
                  'BP',
                  '${recording.healthMetrics['systolic']}/${recording.healthMetrics['diastolic']}',
                  Icons.favorite_border,
                  Colors.orange,
                ),
                _buildMetricDisplay(
                  'SpO2',
                  '${recording.healthMetrics['oxygen']}%',
                  Icons.air,
                  Colors.blue,
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
          ],
        ),
      ),
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
                        'Blood Pressure',
                        '${recording.healthMetrics['systolic'] ?? '--'}/${recording.healthMetrics['diastolic'] ?? '--'} mmHg',
                      ),
                      _buildDetailRow(
                        'SpO2',
                        '${recording.healthMetrics['oxygen'] ?? '--'}%',
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
                      Container(
                        height: 160,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF2F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFFFF9494),
                            width: 1.2,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: recording.ecgData.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No ECG data recorded',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                )
                              : SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: SizedBox(
                                    width: (recording.ecgData.length * 3.0).clamp(
                                      MediaQuery.of(context).size.width - 48,
                                      10000.0,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 8, bottom: 8, right: 16),
                                      child: LineChart(
                                        LineChartData(
                                          minX: 0,
                                          maxX: (recording.ecgData.length - 1).toDouble(),
                                          minY: 0,
                                          maxY: 100,
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
                                          titlesData: const FlTitlesData(show: false),
                                          borderData: FlBorderData(show: false),
                                          lineBarsData: [
                                            LineChartBarData(
                                              spots: List.generate(
                                                recording.ecgData.length,
                                                (i) => FlSpot(
                                                  i.toDouble(),
                                                  (recording.ecgData[i] / 255.0) * 100,
                                                ),
                                              ),
                                              isCurved: true,
                                              color: const Color(0xFF1E1E1E),
                                              barWidth: 1.5,
                                              isStrokeCapRound: true,
                                              dotData: const FlDotData(show: false),
                                              belowBarData: BarAreaData(show: false),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),
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
}
