import 'package:flutter/material.dart';
import 'ecg_recordings_screen.dart';
import '../../widgets/app_bar_profile_avatar.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        elevation: 0,
        actions: const [
          AppBarProfileAvatar(),
        ],
      ),
      body: const ECGRecordingsScreen(showAppBar: false),
    );
  }
}
