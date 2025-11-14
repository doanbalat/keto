import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';

/// Widget that provides notification UI integration with SnackBars
/// and manages notification display
class NotificationManager extends StatelessWidget {
  final Widget child;

  const NotificationManager({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<AppNotification>(
        stream: NotificationService().notificationStream,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final notification = snapshot.data!;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showNotificationSnackBar(context, notification);
            });
          }
          return child;
        },
      ),
    );
  }

  /// Show notification as a SnackBar
  void _showNotificationSnackBar(
    BuildContext context,
    AppNotification notification,
  ) {
    final snackBar = SnackBar(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _getIconForType(notification.type),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: const TextStyle(fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      backgroundColor: _getBackgroundColorForType(notification.type),
      duration: const Duration(seconds: 4),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  /// Get icon widget for notification type
  Widget _getIconForType(NotificationType type) {
    switch (type) {
      case NotificationType.success:
        return const Icon(
          Icons.check_circle_outline,
          color: Colors.white,
          size: 20,
        );
      case NotificationType.error:
        return const Icon(
          Icons.error_outline,
          color: Colors.white,
          size: 20,
        );
      case NotificationType.warning:
        return const Icon(
          Icons.warning_outlined,
          color: Colors.white,
          size: 20,
        );
      case NotificationType.info:
        return const Icon(
          Icons.info_outline,
          color: Colors.white,
          size: 20,
        );
    }
  }

  /// Get background color for notification type
  Color _getBackgroundColorForType(NotificationType type) {
    switch (type) {
      case NotificationType.success:
        return Colors.green.shade600;
      case NotificationType.error:
        return Colors.red.shade600;
      case NotificationType.warning:
        return Colors.orange.shade600;
      case NotificationType.info:
        return Colors.blue.shade600;
    }
  }
}

/// Extension for easier access to NotificationService
extension NotificationExtension on BuildContext {
  /// Get NotificationService from context
  NotificationService get notifications => NotificationService();

  /// Show success notification
  Future<void> showSuccessNotification(String title, String message) =>
      NotificationService().showSuccess(title, message);

  /// Show error notification
  Future<void> showErrorNotification(String title, String message) =>
      NotificationService().showError(title, message);

  /// Show warning notification
  Future<void> showWarningNotification(String title, String message) =>
      NotificationService().showWarning(title, message);

  /// Show info notification
  Future<void> showInfoNotification(String title, String message) =>
      NotificationService().showInfo(title, message);
}
