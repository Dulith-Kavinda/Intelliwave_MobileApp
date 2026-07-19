import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_theme.dart';
import '../../providers/notification_provider.dart';
import '../../models/notification_model.dart';
import '../../widgets/app_bar_profile_avatar.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Notifications'),
        elevation: 0,
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, notifProvider, _) {
              if (notifProvider.allNotifications.isEmpty) {
                return const SizedBox.shrink();
              }
              return Row(
                children: [
                  if (notifProvider.unreadCount > 0)
                    TextButton.icon(
                      onPressed: () {
                        for (final n in notifProvider.allNotifications.where((n) => !n.isRead)) {
                          notifProvider.markAsRead(n.id);
                        }
                      },
                      icon: const Icon(Icons.done_all_rounded, size: 18),
                      label: const Text('Mark all read'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  IconButton(
                    icon: Icon(
                      Icons.delete_sweep_rounded,
                      color: isDark ? Colors.red[300] : Colors.red[700],
                    ),
                    tooltip: 'Clear all',
                    onPressed: () => _showClearDialog(context, notifProvider),
                  ),
                ],
              );
            },
          ),
          const AppBarProfileAvatar(),
        ],
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, notifProvider, _) {
          if (notifProvider.allNotifications.isEmpty) {
            return const _EmptyNotificationsView();
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: notifProvider.allNotifications.length,
            itemBuilder: (context, index) {
              final notification = notifProvider.allNotifications[index];
              return _NotificationCard(notification: notification);
            },
          );
        },
      ),
    );
  }

  void _showClearDialog(BuildContext context, NotificationProvider notifProvider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: AppColors.danger),
            SizedBox(width: 8),
            Text('Clear All'),
          ],
        ),
        content: const Text('Are you sure you want to delete all notifications?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              notifProvider.clearAllNotifications();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ─── Notification Card ────────────────────────────────────────────────────────

class _NotificationCard extends StatelessWidget {
  final AppNotification notification;

  const _NotificationCard({required this.notification});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUnread = !notification.isRead;
    final typeColor = _getTypeColor();
    final typeIcon = _getTypeIcon();
    
    // Robustly check if this is an ECG alert
    final isEcgAnomaly = notification.type == 'alert' &&
        (notification.title.contains('ECG') ||
         notification.title.contains('AFib') ||
         notification.title.contains('Block') ||
         notification.title.contains('PVC') ||
         notification.message.contains('ECG') ||
         notification.message.contains('AFib') ||
         notification.message.contains('BBB') ||
         notification.message.contains('PVC'));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isUnread ? 1 : 0,
      color: isDark
          ? (isUnread ? AppColors.darkSurface2 : AppColors.darkSurface)
          : (isUnread ? Colors.white : AppColors.lightGrey.withValues(alpha: 0.5)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isUnread
              ? typeColor.withValues(alpha: 0.4)
              : (isDark ? AppColors.darkBorder : Colors.grey.withValues(alpha: 0.15)),
          width: isUnread ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          context.read<NotificationProvider>().markAsRead(notification.id);
          _showDetail(context);
        },
        onLongPress: () => _showOptions(context),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon badge
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: typeColor.withValues(alpha: 0.2)),
                    ),
                    child: Icon(typeIcon, color: typeColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  // Title + Timestamp
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                notification.title,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.darkGrey,
                                ),
                              ),
                            ),
                            if (isUnread)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: typeColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatTime(notification.timestamp),
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.darkTextMuted : AppColors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Message
              Text(
                notification.message,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.darkTextSecondary : Colors.black87,
                  height: 1.4,
                ),
              ),
              // ECG Anomaly Chips if applicable
              if (isEcgAnomaly) ...[
                const SizedBox(height: 10),
                _EcgConditionChips(message: notification.message, typeColor: typeColor),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getTypeColor() {
    switch (notification.type) {
      case 'alert':
      case 'important':
        return AppColors.danger;
      case 'warning':
        return AppColors.warning;
      case 'success':
        return AppColors.success;
      case 'info':
      default:
        return AppColors.primary;
    }
  }

  IconData _getTypeIcon() {
    if (notification.title.contains('ECG') ||
        notification.message.contains('ECG') ||
        notification.title.contains('AFib') ||
        notification.title.contains('Block') ||
        notification.title.contains('PVC')) {
      return Icons.monitor_heart_rounded;
    }
    switch (notification.type) {
      case 'alert':
      case 'important':
        return Icons.error_outline_rounded;
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'success':
        return Icons.check_circle_outline_rounded;
      case 'info':
      default:
        return Icons.info_outline_rounded;
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    if (difference.inSeconds < 60) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _NotificationDetailSheet(
        notification: notification,
        typeColor: _getTypeColor(),
        typeIcon: _getTypeIcon(),
      ),
    );
  }

  void _showOptions(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!notification.isRead)
              ListTile(
                leading: const Icon(Icons.mark_chat_read_rounded, color: AppColors.success),
                title: const Text('Mark as Read'),
                onTap: () {
                  context.read<NotificationProvider>().markAsRead(notification.id);
                  Navigator.pop(context);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_rounded, color: AppColors.danger),
              title: const Text('Delete'),
              onTap: () {
                context.read<NotificationProvider>().deleteNotification(notification.id);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─── ECG Condition Chips ──────────────────────────────────────────────────────

class _EcgConditionChips extends StatelessWidget {
  final String message;
  final Color typeColor;

  const _EcgConditionChips({required this.message, required this.typeColor});

  @override
  Widget build(BuildContext context) {
    String condition = '';
    if (message.contains('Myocardial Infarction') || message.contains('MI')) {
      condition = 'Myocardial Infarction (MI)';
    } else if (message.contains('ST/T') || message.contains('STTC')) {
      condition = 'ST/T Change (STTC)';
    } else if (message.contains('Conduction Disturbance') || message.contains('CD')) {
      condition = 'Conduction Disturbance (CD)';
    } else if (message.contains('Hypertrophy') || message.contains('HYP')) {
      condition = 'Hypertrophy (HYP)';
    }

    final confMatch = RegExp(r'\((\d+)%').firstMatch(message);
    final confidence = confMatch?.group(1) ?? '';

    if (condition.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        Chip(
          labelPadding: const EdgeInsets.symmetric(horizontal: 4),
          avatar: Icon(Icons.monitor_heart, size: 14, color: typeColor),
          label: Text(
            condition,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: typeColor),
          ),
          backgroundColor: typeColor.withValues(alpha: 0.1),
          side: BorderSide(color: typeColor.withValues(alpha: 0.25)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          visualDensity: VisualDensity.compact,
        ),
        if (confidence.isNotEmpty)
          Chip(
            labelPadding: const EdgeInsets.symmetric(horizontal: 4),
            avatar: const Icon(Icons.analytics_outlined, size: 14),
            label: Text(
              '$confidence% Confidence',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
            backgroundColor: Colors.grey.withValues(alpha: 0.1),
            side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }
}

// ─── Notification Detail Sheet ────────────────────────────────────────────────

class _NotificationDetailSheet extends StatelessWidget {
  final AppNotification notification;
  final Color typeColor;
  final IconData typeIcon;

  const _NotificationDetailSheet({
    required this.notification,
    required this.typeColor,
    required this.typeIcon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBorder : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: typeColor.withValues(alpha: 0.2)),
                ),
                child: Icon(typeIcon, color: typeColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _fullTime(notification.timestamp),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? AppColors.darkTextMuted : AppColors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface2 : AppColors.lightGrey.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : Colors.grey.withValues(alpha: 0.15),
              ),
            ),
            child: Text(
              notification.message,
              style: theme.textTheme.bodyLarge?.copyWith(fontSize: 14),
            ),
          ),
          if (notification.title.contains('ECG') || notification.message.contains('ECG') ||
              notification.message.contains('AFib') || notification.message.contains('BBB')) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.info.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppColors.info, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'AI predictions are for educational reference and initial screening. Consult a medical professional for clinical guidance.',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.primaryLight : AppColors.info,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    context.read<NotificationProvider>().deleteNotification(notification.id);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                  child: const Text('Delete'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fullTime(DateTime time) {
    return '${time.day}/${time.month}/${time.year} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

// ─── Empty State View ─────────────────────────────────────────────────────────

class _EmptyNotificationsView extends StatelessWidget {
  const _EmptyNotificationsView();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightGrey,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_off_outlined,
              size: 38,
              color: isDark ? AppColors.darkTextMuted : AppColors.grey,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'All Caught Up!',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkTextPrimary : AppColors.darkGrey,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'No notifications yet.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.darkTextMuted : AppColors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
