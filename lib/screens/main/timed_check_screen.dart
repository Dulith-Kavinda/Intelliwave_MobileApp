import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_theme.dart';
import '../../providers/timed_check_provider.dart';
import '../../models/timed_check_session.dart';
import '../../providers/auth_provider.dart';

class TimedCheckScreen extends StatefulWidget {
  const TimedCheckScreen({Key? key}) : super(key: key);

  @override
  State<TimedCheckScreen> createState() => _TimedCheckScreenState();
}

class _TimedCheckScreenState extends State<TimedCheckScreen> {
  int _selectedDuration = 5; // in minutes
  final List<int> _durationOptions = [1, 5, 10, 15, 30];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Timed Health Check'),
        elevation: 0,
      ),
      body: Consumer<TimedCheckProvider>(
        builder: (context, timedCheckProvider, _) {
          if (timedCheckProvider.hasActiveSession) {
            return _ActiveSessionView(session: timedCheckProvider.currentSession!);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Monitor Your Health',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Set a duration to continuously monitor your heart rate and get automatic health analysis.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.grey,
                      ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Select Duration',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _durationOptions.length,
                  itemBuilder: (context, index) {
                    final duration = _durationOptions[index];
                    final isSelected = duration == _selectedDuration;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedDuration = duration);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.lightGrey,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '$duration min',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.primary,
                                ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'What this does',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 12),
                        _InfoBullet(
                          text: 'Continuously monitors your heart rate',
                        ),
                        _InfoBullet(
                          text: 'Records heart rate data every few seconds',
                        ),
                        _InfoBullet(
                          text: 'Analyzes patterns using AI',
                        ),
                        _InfoBullet(
                          text: 'Provides health recommendations at the end',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _startTimedCheck(context, timedCheckProvider);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    icon: const Icon(Icons.play_circle_filled),
                    label: Text('Start $_selectedDuration Minute Check'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _startTimedCheck(
    BuildContext context,
    TimedCheckProvider timedCheckProvider,
  ) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.currentUserModel?.uid ?? 'test_user';

    // Start timed check session
    timedCheckProvider.startTimedCheck(
      userId: userId,
      durationMinutes: _selectedDuration,
    );
  }
}

class _ActiveSessionView extends StatelessWidget {
  final TimedCheckSession session;

  const _ActiveSessionView({required this.session});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Health Check in Progress',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 32),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 200,
                  height: 200,
                  child: CircularProgressIndicator(
                    value: session.progressPercentage,
                    strokeWidth: 8,
                    valueColor: AlwaysStoppedAnimation(
                      AppColors.primary,
                    ),
                  ),
                ),
                Column(
                  children: [
                    Text(
                      '${session.remainingMinutes}:00',
                      style:
                          Theme.of(context).textTheme.displaySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'minutes remaining',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.grey,
                          ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Session Data',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    _DetailRow(
                      label: 'Data Points',
                      value: '${session.heartbeatDataIds.length}',
                    ),
                    const Divider(),
                    _DetailRow(
                      label: 'Duration',
                      value: '${session.durationMinutes} minutes',
                    ),
                    const Divider(),
                    _DetailRow(
                      label: 'Status',
                      value: session.status.toUpperCase(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Pause session
                      context.read<TimedCheckProvider>().pauseSession();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.warning,
                    ),
                    icon: const Icon(Icons.pause),
                    label: const Text('Pause'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Complete session
                      context.read<TimedCheckProvider>().completeSession(
                            healthCondition:
                                'Analyzing...', // This will be updated by AI
                          );
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                    ),
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Complete'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoBullet extends StatelessWidget {
  final String text;

  const _InfoBullet({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Icon(
              Icons.check_circle,
              size: 20,
              color: AppColors.success,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text),
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
      padding: const EdgeInsets.symmetric(vertical: 8),
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
