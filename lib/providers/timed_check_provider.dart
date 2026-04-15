import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../models/timed_check_session.dart';
import 'dart:async';
import 'package:uuid/uuid.dart';

class TimedCheckProvider extends ChangeNotifier {
  final StorageService _storageService;

  TimedCheckSession? _currentSession;
  List<TimedCheckSession> _allSessions = [];
  Timer? _sessionTimer;
  bool _isLoading = false;
  String? _errorMessage;

  TimedCheckSession? get currentSession => _currentSession;
  List<TimedCheckSession> get allSessions => _allSessions;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasActiveSession => _currentSession != null && _currentSession!.isOngoing;

  TimedCheckProvider(this._storageService) {
    _loadSessions();
  }

  void _loadSessions() {
    try {
      _allSessions = _storageService.getAllSessions();
      // Find any ongoing session
      _currentSession =
          _allSessions.where((s) => s.isOngoing).firstOrNull;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> startTimedCheck({
    required String userId,
    required int durationMinutes,
  }) async {
    try {
      final startTime = DateTime.now();
      final endTime = startTime.add(Duration(minutes: durationMinutes));

      final session = TimedCheckSession(
        id: const Uuid().v4(),
        userId: userId,
        startTime: startTime,
        endTime: endTime,
        durationMinutes: durationMinutes,
        status: 'ongoing',
        createdAt: startTime,
      );

      await _storageService.saveSession(session);
      _currentSession = session;
      _allSessions.add(session);

      _startSessionTimer();
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  void _startSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_currentSession != null && _currentSession!.isOngoing) {
        if (DateTime.now().isAfter(_currentSession!.endTime)) {
          // Session completed
          completeSession();
        } else {
          notifyListeners();
        }
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> addHeartbeatToSession(String heartbeatDataId) async {
    if (_currentSession != null) {
      try {
        final updated = _currentSession!.copyWith(
          heartbeatDataIds: [
            ..._currentSession!.heartbeatDataIds,
            heartbeatDataId,
          ],
        );

        await _storageService.updateSession(updated);
        _currentSession = updated;
        notifyListeners();
      } catch (e) {
        _errorMessage = e.toString();
        notifyListeners();
      }
    }
  }

  Future<void> completeSession({String? aiAnalysis, String? healthCondition}) async {
    if (_currentSession != null) {
      try {
        final completed = _currentSession!.copyWith(
          status: 'completed',
          aiAnalysis: aiAnalysis,
          healthCondition: healthCondition,
        );

        await _storageService.updateSession(completed);
        _currentSession = null;
        _sessionTimer?.cancel();
        notifyListeners();
      } catch (e) {
        _errorMessage = e.toString();
        notifyListeners();
      }
    }
  }

  Future<void> pauseSession() async {
    if (_currentSession != null) {
      try {
        final paused = _currentSession!.copyWith(status: 'paused');
        await _storageService.updateSession(paused);
        _currentSession = paused;
        _sessionTimer?.cancel();
        notifyListeners();
      } catch (e) {
        _errorMessage = e.toString();
        notifyListeners();
      }
    }
  }

  Future<void> resumeSession() async {
    if (_currentSession != null && _currentSession!.status == 'paused') {
      try {
        final resumed = _currentSession!.copyWith(status: 'ongoing');
        await _storageService.updateSession(resumed);
        _currentSession = resumed;
        _startSessionTimer();
        notifyListeners();
      } catch (e) {
        _errorMessage = e.toString();
        notifyListeners();
      }
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    super.dispose();
  }
}
