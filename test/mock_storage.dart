/// Mock implementation of SharedPreferences for testing
/// This allows tests to run without platform channels
class MockSharedPreferences {
  static final MockSharedPreferences _instance = MockSharedPreferences._internal();
  
  factory MockSharedPreferences() {
    return _instance;
  }
  
  MockSharedPreferences._internal();
  
  final Map<String, dynamic> _storage = {};
  
  static MockSharedPreferences getInstance() {
    return _instance;
  }
  
  /// Get all stored data
  Map<String, Object> getAll() {
    return Map.from(_storage);
  }
  
  /// Get string value
  String? getString(String key) {
    return _storage[key] as String?;
  }
  
  /// Set string value
  Future<bool> setString(String key, String value) async {
    _storage[key] = value;
    return true;
  }
  
  /// Get bool value
  bool? getBool(String key) {
    return _storage[key] as bool?;
  }
  
  /// Set bool value
  Future<bool> setBool(String key, bool value) async {
    _storage[key] = value;
    return true;
  }
  
  /// Remove key
  Future<bool> remove(String key) async {
    _storage.remove(key);
    return true;
  }
  
  /// Clear all
  Future<bool> clear() async {
    _storage.clear();
    return true;
  }
  
  /// Check if key exists
  bool containsKey(String key) {
    return _storage.containsKey(key);
  }
}

/// Mock GotrueAsyncStorage for Supabase
class MockGotrueAsyncStorage {
  final Map<String, String> _data = {};
  
  Future<String?> getItem(String key) async {
    return _data[key];
  }
  
  Future<void> setItem(String key, String value) async {
    _data[key] = value;
  }
  
  Future<void> removeItem(String key) async {
    _data.remove(key);
  }
  
  Future<void> clear() async {
    _data.clear();
  }
}
