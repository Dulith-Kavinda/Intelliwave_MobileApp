import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../models/heartbeat_data.dart';

class HeartbeatProvider extends ChangeNotifier {
  final StorageService _storageService;

  List<HeartbeatData> _allHeartbeatData = [];
  List<HeartbeatData> _filteredData = [];
  bool _isLoading = false;
  String? _errorMessage;
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;

  List<HeartbeatData> get allHeartbeatData => _allHeartbeatData;
  List<HeartbeatData> get filteredData => _filteredData;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  DateTime? get filterStartDate => _filterStartDate;
  DateTime? get filterEndDate => _filterEndDate;

  int get averageHeartRate {
    if (_filteredData.isEmpty) return 0;
    final sum = _filteredData.fold<int>(0, (sum, data) => sum + data.heartRate);
    return (sum / _filteredData.length).toInt();
  }

  int get maxHeartRate {
    if (_filteredData.isEmpty) return 0;
    return _filteredData.map((d) => d.heartRate).reduce((max, current) => current > max ? current : max);
  }

  int get minHeartRate {
    if (_filteredData.isEmpty) return 0;
    return _filteredData.map((d) => d.heartRate).reduce((min, current) => current < min ? current : min);
  }

  HeartbeatProvider(this._storageService);

  Future<void> loadHeartbeatData(String userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _allHeartbeatData = _storageService.getHeartbeatDataByUserId(userId);
      _filteredData = _allHeartbeatData;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addHeartbeatData(HeartbeatData data) async {
    try {
      await _storageService.saveHeartbeatData(data);
      _allHeartbeatData.add(data);
      _filteredData.add(data);
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  void filterByDateRange(DateTime startDate, DateTime endDate) {
    _filterStartDate = startDate;
    _filterEndDate = endDate;

    _filteredData = _allHeartbeatData
        .where((data) =>
            data.timestamp.isAfter(startDate) &&
            data.timestamp.isBefore(endDate.add(const Duration(days: 1))))
        .toList();

    notifyListeners();
  }

  void filterByDate(DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    filterByDateRange(startOfDay, endOfDay);
  }

  void clearFilter() {
    _filteredData = _allHeartbeatData;
    _filterStartDate = null;
    _filterEndDate = null;
    notifyListeners();
  }

  Future<void> deleteHeartbeatData(String id) async {
    try {
      await _storageService.deleteHeartbeatData(id);
      _allHeartbeatData.removeWhere((data) => data.id == id);
      _filteredData.removeWhere((data) => data.id == id);
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
