import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../constants/app_theme.dart';
import '../../models/ecg_recording_model.dart';

class ECGRecordingsScreen extends StatefulWidget {
  final List<ECGRecording>? initialRecordings;

  const ECGRecordingsScreen({
    Key? key,
    this.initialRecordings,
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
    // Initialize with sample recordings if none provided
    _allRecordings = widget.initialRecordings ?? [];
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ECG Recordings'),
        elevation: 0,
      ),
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
                                        : AppColors.darkGrey,
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
            color: Colors.grey[300],
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Recording downloaded'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('Export'),
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
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recording Details',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 24),
                _buildDetailRow('Device', recording.deviceName),
                _buildDetailRow('Date', recording.getFormattedDate()),
                _buildDetailRow('Duration', recording.getFormattedDuration()),
                _buildDetailRow(
                  'Heart Rate',
                  '${recording.getHeartRate()} BPM',
                ),
                _buildDetailRow(
                  'Blood Pressure',
                  '${recording.healthMetrics['systolic']}/${recording.healthMetrics['diastolic']} mmHg',
                ),
                _buildDetailRow(
                  'SpO2',
                  '${recording.healthMetrics['oxygen']}%',
                ),
                _buildDetailRow(
                  'Signal Quality',
                  recording.healthMetrics['quality'] ?? 'N/A',
                ),
                if (recording.notes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildDetailRow('Notes', recording.notes),
                ],
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
