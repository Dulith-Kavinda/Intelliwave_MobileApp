import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/storage_service.dart';
import '../models/notification_model.dart';

class NotificationProvider extends ChangeNotifier {
  final StorageService _storageService;
  late final SupabaseClient _supabase;

  List<AppNotification> _allNotifications = [];
  bool _isLoading = false;
  String? _errorMessage;
  RealtimeChannel? _notificationSubscription;

  List<AppNotification> get allNotifications => _allNotifications;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  int get unreadCount => _allNotifications.where((n) => !n.isRead).length;
  int get importantCount =>
      _allNotifications.where((n) => n.isImportant && !n.isRead).length;

  List<AppNotification> get importantNotifications =>
      _allNotifications.where((n) => n.isImportant).toList();

  NotificationProvider(this._storageService) {
    _supabase = Supabase.instance.client;
    _loadNotifications();
    _subscribeToRealtimeNotifications();
  }

  void _loadNotifications() {
    try {
      _allNotifications = _storageService.getAllNotifications();
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Sync notifications from Supabase cloud into local Hive storage
  /// This is typically called on app startup or periodically
  Future<void> syncNotificationsFromCloud() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        _errorMessage = 'User not authenticated';
        _isLoading = false;
        notifyListeners();
        return;
      }

      final response = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(100); // Limit to last 100 notifications

      // Save each notification to local Hive
      for (var notificationMap in response) {
        final notification = AppNotification.fromMap(notificationMap);
        
        // Only save if not already local (avoid duplicates)
        final exists = _allNotifications.any((n) => n.id == notification.id);
        if (!exists) {
          await _storageService.saveNotification(notification);
          _allNotifications.insert(0, notification); // Add to top of list
        }
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to sync notifications: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Push an important notification to Supabase cloud for backup and multi-device access
  /// Non-important notifications stay local only
  Future<void> pushNotificationToCloud(AppNotification notification) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Only push important or alert-type notifications to cloud
      if (!notification.isImportant && notification.type != 'alert') {
        return; // Local only for regular notifications
      }

      await _supabase
          .from('notifications')
          .upsert({
            'id': notification.id,
            'user_id': userId,
            'title': notification.title,
            'message': notification.message,
            'type': notification.type,
            'is_read': notification.isRead,
            'is_important': notification.isImportant,
            'created_at': notification.timestamp.toIso8601String(),
          });
    } catch (e) {
      print('Error pushing notification to cloud: $e');
      // Continue silently - cloud sync is not critical
    }
  }

  /// Subscribe to real-time notification updates from Supabase
  /// This allows instant multi-device synchronization
  void _subscribeToRealtimeNotifications() {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        return; // Not logged in
      }

      _notificationSubscription = _supabase
          .channel('notifications:user_id.eq.$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) {
              _handleRealtimeNotification(payload);
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) {
              _handleRealtimeNotificationUpdate(payload);
            },
          )
          .subscribe();
    } catch (e) {
      print('Error subscribing to realtime notifications: $e');
    }
  }

  /// Handle new notification from realtime subscription
  void _handleRealtimeNotification(PostgresChangePayload payload) {
    try {
      final notification = AppNotification.fromMap(
        Map<String, dynamic>.from(payload.newRecord),
      );

      // Save to local storage
      _storageService.saveNotification(notification);

      // Add to UI list if not already there
      final exists = _allNotifications.any((n) => n.id == notification.id);
      if (!exists) {
        _allNotifications.insert(0, notification);
        notifyListeners();
      }
    } catch (e) {
      print('Error handling realtime notification: $e');
    }
  }

  /// Handle updated notification from realtime subscription
  void _handleRealtimeNotificationUpdate(PostgresChangePayload payload) {
    try {
      final updatedNotification = AppNotification.fromMap(
        Map<String, dynamic>.from(payload.newRecord),
      );

      // Find and update in local list
      final index = _allNotifications.indexWhere(
        (n) => n.id == updatedNotification.id,
      );

      if (index != -1) {
        _allNotifications[index] = updatedNotification;
        _storageService.saveNotification(updatedNotification);
        notifyListeners();
      }
    } catch (e) {
      print('Error handling realtime update: $e');
    }
  }

  /// Mark notification as read locally and sync to cloud
  Future<void> markAsRead(String id) async {
    try {
      await _storageService.markNotificationAsRead(id);
      final index = _allNotifications.indexWhere((n) => n.id == id);
      if (index != -1) {
        final updated = _allNotifications[index].copyWith(isRead: true);
        _allNotifications[index] = updated;
        
        // Sync to cloud if it's an important notification
        if (updated.isImportant) {
          await _syncReadStatusToCloud(id);
        }
      }
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Sync read status to cloud (for important notifications)
  Future<void> _syncReadStatusToCloud(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (e) {
      print('Error syncing read status to cloud: $e');
    }
  }

  /// Add a new notification locally (doesn't automatically go to cloud)
  /// Use pushNotificationToCloud() separately for cloud sync
  Future<void> addNotification(AppNotification notification) async {
    try {
      await _storageService.saveNotification(notification);
      _allNotifications.insert(0, notification);
      notifyListeners();
      
      // Auto-push important notifications to cloud
      if (notification.isImportant) {
        await pushNotificationToCloud(notification);
      }
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Delete notification locally and from cloud
  Future<void> deleteNotification(String id) async {
    try {
      await _storageService.deleteNotification(id);
      _allNotifications.removeWhere((n) => n.id == id);
      
      // Also delete from cloud
      await _supabase
          .from('notifications')
          .delete()
          .eq('id', id)
          .catchError((_) {}); // Silently fail if not in cloud

      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Clear all notifications locally (optional: can also clear from cloud)
  Future<void> clearAllNotifications({bool includeCloud = false}) async {
    try {
      for (final notification in [..._allNotifications]) {
        await _storageService.deleteNotification(notification.id);
        
        if (includeCloud) {
          await _supabase
              .from('notifications')
              .delete()
              .eq('id', notification.id)
              .catchError((_) {});
        }
      }
      _allNotifications.clear();
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

  /// Clean up subscriptions when provider is disposed
  @override
  void dispose() {
    _notificationSubscription?.unsubscribe();
    super.dispose();
  }
}

