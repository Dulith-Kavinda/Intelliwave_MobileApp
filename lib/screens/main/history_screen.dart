import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../constants/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../models/heartbeat_data.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  DateTime? _selectedDate;
  final List<HeartbeatData> _sampleData = [
    HeartbeatData(
      id: '1',
      userId: 'user1',
      heartRate: 72,
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      deviceId: 'device1',
      status: 'good',
      ecgData: [],
    ),
    HeartbeatData(
      id: '2',
      userId: 'user1',
      heartRate: 85,
      timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      deviceId: 'device1',
      status: 'normal',
      ecgData: [],
    ),
    HeartbeatData(
      id: '3',
      userId: 'user1',
      heartRate: 95,
      timestamp: DateTime.now(),
      deviceId: 'device1',
      status: 'normal',
      ecgData: [],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Heart Rate History'),
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _selectDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.lightGrey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedDate != null
                                  ? DateFormat('dd/MM/yyyy').format(_selectedDate!)
                                  : 'Select Date',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (_selectedDate != null)
                  IconButton(
                    onPressed: () {
                      setState(() => _selectedDate = null);
                    },
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _sampleData.isEmpty
                ? EmptyState(
                    title: 'No History',
                    subtitle: 'No heart rate data found',
                    icon: Icons.history,
                  )
                : ListView.builder(
                    itemCount: _sampleData.length,
                    itemBuilder: (context, index) {
                      final data = _sampleData[index];
                      return _HistoryCard(heartbeatData: data);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }
}

class _HistoryCard extends StatelessWidget {
  final HeartbeatData heartbeatData;

  const _HistoryCard({required this.heartbeatData});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _getStatusColor().withOpacity(0.2),
          ),
          child: Center(
            child: Icon(
              Icons.favorite,
              color: _getStatusColor(),
            ),
          ),
        ),
        title: Text('${heartbeatData.heartRate} BPM'),
        subtitle: Text(
          DateFormat('dd/MM/yyyy - HH:mm').format(heartbeatData.timestamp),
        ),
        trailing: HealthStatusBadge(
          status: heartbeatData.status,
        ),
        onTap: () {
          // Show detailed view
          showModalBottomSheet(
            context: context,
            builder: (context) => _HistoryDetailsView(data: heartbeatData),
          );
        },
      ),
    );
  }

  Color _getStatusColor() {
    switch (heartbeatData.status) {
      case 'good':
        return AppColors.heartRateGood;
      case 'normal':
        return AppColors.heartRateNormal;
      case 'poor':
        return AppColors.heartRatePoor;
      default:
        return AppColors.grey;
    }
  }
}

class _HistoryDetailsView extends StatelessWidget {
  final HeartbeatData data;

  const _HistoryDetailsView({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Heart Rate Details',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 24),
          _DetailRow(label: 'Heart Rate', value: '${data.heartRate} BPM'),
          _DetailRow(
            label: 'Time',
            value: DateFormat('dd/MM/yyyy - HH:mm').format(data.timestamp),
          ),
          _DetailRow(label: 'Status', value: data.status.toUpperCase()),
          if (data.oxygenLevel != null)
            _DetailRow(label: 'Oxygen Level', value: '${data.oxygenLevel}%'),
          if (data.systolic != null && data.diastolic != null)
            _DetailRow(
              label: 'Blood Pressure',
              value: '${data.systolic}/${data.diastolic} mmHg',
            ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Share functionality
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Share coming soon')),
                    );
                  },
                  icon: const Icon(Icons.share),
                  label: const Text('Share'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // View as ECG graph
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.info,
                  ),
                  icon: const Icon(Icons.show_chart),
                  label: const Text('ECG Graph'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.grey,
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }
}
