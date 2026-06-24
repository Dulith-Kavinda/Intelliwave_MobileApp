import 'package:flutter/material.dart';
import '../../constants/app_theme.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({Key? key}) : super(key: key);

  static final List<_FaqItem> _faqs = [
    _FaqItem(
      question: 'How do I connect my ECG device?',
      answer:
          'Go to the Dashboard and tap "Connect Device" or navigate to the Device Scanner from the menu. Make sure your Bluetooth ECG device is turned on and in pairing mode. The app will automatically scan and display nearby devices. Tap your device to connect.',
      icon: Icons.bluetooth,
    ),
    _FaqItem(
      question: 'Why is my ECG graph not showing data?',
      answer:
          'Ensure your device is connected (you\'ll see a green "Connected" status on the dashboard). Check that the device electrodes are properly attached. If the issue persists, try disconnecting and reconnecting the device from the Device Scanner screen.',
      icon: Icons.monitor_heart,
    ),
    _FaqItem(
      question: 'How do I record an ECG session?',
      answer:
          'From the Dashboard, tap the red "Record" button when your device is connected. The recording will start automatically. Tap "Stop" when done. Recordings are saved locally and can be viewed in the ECG Recordings section.',
      icon: Icons.fiber_manual_record,
    ),
    _FaqItem(
      question: 'How do I view my heart rate history?',
      answer:
          'Navigate to the "History" tab from the bottom navigation bar. You\'ll see a graph of your heart rate readings over time, along with statistics like minimum, maximum, and average heart rate.',
      icon: Icons.history,
    ),
    _FaqItem(
      question: 'Can I export my ECG data?',
      answer:
          'Yes! Go to ECG Recordings, open any recording, and tap the share icon. You can export the data as a PDF report or share the raw data. This is useful for sharing with your doctor.',
      icon: Icons.share,
    ),
    _FaqItem(
      question: 'How do I update my profile picture?',
      answer:
          'Go to the Profile tab and tap the camera icon on your profile picture. You can choose to take a new photo with your camera or pick one from your gallery. The photo will be automatically uploaded and saved.',
      icon: Icons.camera_alt,
    ),
    _FaqItem(
      question: 'What does the heart rate status mean?',
      answer:
          'Green = Normal range (60-100 bpm for adults at rest). Yellow = Borderline (50-60 or 100-110 bpm). Red = Out of normal range (< 50 or > 110 bpm). These are general guidelines — consult your doctor for personalized thresholds.',
      icon: Icons.favorite,
    ),
    _FaqItem(
      question: 'Is my health data secure?',
      answer:
          'Yes. Your profile data is encrypted and stored in a secure cloud database with row-level security. Health data (ECG recordings, heart rate history) is stored locally on your device only. We never sell your data. See our Privacy Policy for details.',
      icon: Icons.security,
    ),
    _FaqItem(
      question: 'How do I set up heart rate alerts?',
      answer:
          'Go to Settings > Notifications and enable "Heart Rate Alerts". You can configure high and low threshold values. When your heart rate exceeds these thresholds during monitoring, you\'ll receive a notification.',
      icon: Icons.notifications,
    ),
    _FaqItem(
      question: 'How do I delete my account?',
      answer:
          'Go to Profile, scroll down, and tap "Delete Account". This will permanently delete your profile data from our servers. Local health data will remain on your device until you uninstall the app.',
      icon: Icons.delete_forever,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & FAQ'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.warning.withOpacity(0.12),
                  AppColors.warning.withOpacity(0.04),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.warning.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.warning,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.help_outline,
                      color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Frequently Asked Questions',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.warning,
                                ),
                      ),
                      Text(
                        'Find answers to common questions',
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.grey,
                                ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // FAQ items
          ...List.generate(
            _faqs.length,
            (index) => _FaqTile(item: _faqs[index]),
          ),

          const SizedBox(height: 20),

          // Still need help?
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.1),
                  AppColors.primaryLight.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                const Icon(Icons.support_agent,
                    color: AppColors.primary, size: 40),
                const SizedBox(height: 12),
                Text(
                  'Still need help?',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Our support team is ready to assist you.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.grey,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        Navigator.of(context).pushNamed('/contact'),
                    icon: const Icon(Icons.email_outlined),
                    label: const Text('Contact Support'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _FaqItem {
  final String question;
  final String answer;
  final IconData icon;

  const _FaqItem({
    required this.question,
    required this.answer,
    required this.icon,
  });
}

class _FaqTile extends StatefulWidget {
  final _FaqItem item;

  const _FaqTile({required this.item});

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _controller;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isExpanded
              ? AppColors.primary.withOpacity(0.4)
              : Colors.transparent,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: _toggle,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(widget.item.icon,
                        color: AppColors.primary, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.item.question,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: const Icon(Icons.keyboard_arrow_down,
                        color: AppColors.grey),
                  ),
                ],
              ),
            ),
          ),
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Text(
                    widget.item.answer,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.grey,
                          height: 1.6,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
