import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'dart:convert';
import 'dart:async';
import '../models/notification_model.dart';

/// Service for managing local notifications in the application
/// 
/// Handles displaying notifications, managing notification history,
/// and interacting with the native notification system
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  static const String _notificationHistoryKey = 'notification_history';
  static const String _maxHistoryKey = 'max_history_size';
  static const int _defaultMaxHistory = 100;

  late FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin;
  final List<AppNotification> _notifications = [];
  final StreamController<AppNotification> _notificationStream =
      StreamController<AppNotification>.broadcast();
  late StreamController<List<AppNotification>> _historyStream;

  NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  /// Initialize the notification service
  /// Should be called in main() before runApp()
  Future<void> init() async {
    try {
      _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

      // Android initialization
      const AndroidInitializationSettings androidInitialize =
          AndroidInitializationSettings('@mipmap/launcher_icon');

      // iOS initialization
      const DarwinInitializationSettings iOSInitialize =
          DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
        requestCriticalPermission: false,
      );

      const InitializationSettings initSettings = InitializationSettings(
        android: androidInitialize,
        iOS: iOSInitialize,
      );

      await _flutterLocalNotificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Request iOS permissions
      await _requestiOSPermissions();

      // Create Android notification channels
      await _createAndroidNotificationChannels();

      // Load notification history from SharedPreferences
      await _loadNotificationHistory();

      // Initialize history stream
      _historyStream = StreamController<List<AppNotification>>.broadcast();

      if (kDebugMode) print('NotificationService initialized successfully');
    } catch (e) {
      if (kDebugMode) print('Error initializing NotificationService: $e');
      // Continue without notifications rather than crashing the app
      _historyStream = StreamController<List<AppNotification>>.broadcast();
    }
  }

  /// Request iOS notification permissions
  Future<void> _requestiOSPermissions() async {
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  /// Create Android notification channels for different notification types
  Future<void> _createAndroidNotificationChannels() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      await androidImplementation.createNotificationChannel(
        const AndroidNotificationChannel(
          'success_notifications',
          'Success Notifications',
          description: 'Successful operations notifications',
          importance: Importance.defaultImportance,
        ),
      );

      await androidImplementation.createNotificationChannel(
        const AndroidNotificationChannel(
          'error_notifications',
          'Error Notifications',
          description: 'Error and warning notifications',
          importance: Importance.high,
        ),
      );

      await androidImplementation.createNotificationChannel(
        const AndroidNotificationChannel(
          'info_notifications',
          'Information',
          description: 'Information and alerts',
          importance: Importance.defaultImportance,
        ),
      );

      await androidImplementation.createNotificationChannel(
        const AndroidNotificationChannel(
          'warning_notifications',
          'Warnings',
          description: 'Warning notifications',
          importance: Importance.defaultImportance,
        ),
      );
    }
  }

  /// Callback when notification is tapped
  void _onNotificationTapped(NotificationResponse response) {
    if (kDebugMode) print('Notification tapped: ${response.payload}');
  }

  /// Show a notification with the given type, title, and message
  Future<void> showNotification({
    required String title,
    required String message,
    required NotificationType type,
    Duration displayDuration = const Duration(seconds: 4),
  }) async {
    final notification = AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      message: message,
      type: type,
      createdAt: DateTime.now(),
    );

    _notifications.add(notification);
    _notificationStream.add(notification);

    // Save to history
    await _saveNotificationToHistory(notification);

    // Show native notification
    await _showPlatformNotification(notification);

    if (kDebugMode) print('Notification shown: ${notification.title}');
  }

  /// Show success notification
  Future<void> showSuccess(
    String title,
    String message, {
    Duration displayDuration = const Duration(seconds: 3),
  }) =>
      showNotification(
        title: title,
        message: message,
        type: NotificationType.success,
        displayDuration: displayDuration,
      );

  /// Show error notification
  Future<void> showError(
    String title,
    String message, {
    Duration displayDuration = const Duration(seconds: 4),
  }) =>
      showNotification(
        title: title,
        message: message,
        type: NotificationType.error,
        displayDuration: displayDuration,
      );

  /// Show warning notification
  Future<void> showWarning(
    String title,
    String message, {
    Duration displayDuration = const Duration(seconds: 4),
  }) =>
      showNotification(
        title: title,
        message: message,
        type: NotificationType.warning,
        displayDuration: displayDuration,
      );

  /// Show info notification
  Future<void> showInfo(
    String title,
    String message, {
    Duration displayDuration = const Duration(seconds: 3),
  }) =>
      showNotification(
        title: title,
        message: message,
        type: NotificationType.info,
        displayDuration: displayDuration,
      );

  /// Display the native platform notification
  Future<void> _showPlatformNotification(AppNotification notification) async {
    final channelId = _getChannelIdForType(notification.type);

    await _flutterLocalNotificationsPlugin.show(
      notification.id.hashCode,
      notification.title,
      notification.message,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          _getChannelNameForType(notification.type),
          priority: Priority.high,
          enableVibration: notification.type == NotificationType.error ||
              notification.type == NotificationType.warning,
          playSound: notification.type == NotificationType.error ||
              notification.type == NotificationType.warning,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  /// Get notification channel ID for the notification type
  String _getChannelIdForType(NotificationType type) {
    switch (type) {
      case NotificationType.success:
        return 'success_notifications';
      case NotificationType.error:
        return 'error_notifications';
      case NotificationType.warning:
        return 'warning_notifications';
      case NotificationType.info:
        return 'info_notifications';
    }
  }

  /// Get notification channel name for the notification type
  String _getChannelNameForType(NotificationType type) {
    switch (type) {
      case NotificationType.success:
        return 'Success Notifications';
      case NotificationType.error:
        return 'Error Notifications';
      case NotificationType.warning:
        return 'Warning Notifications';
      case NotificationType.info:
        return 'Information';
    }
  }

  /// Get importance level for the notification type
  /// Save notification to SharedPreferences history
  Future<void> _saveNotificationToHistory(AppNotification notification) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = _loadNotificationHistorySync();

      // Limit history size
      final maxHistory =
          prefs.getInt(_maxHistoryKey) ?? _defaultMaxHistory;
      if (history.length >= maxHistory) {
        history.removeAt(0); // Remove oldest notification
      }

      history.add(notification);

      final jsonList =
          history.map((n) => jsonEncode(n.toJson())).toList();
      await prefs.setStringList(_notificationHistoryKey, jsonList);

      // Emit update to history stream
      _historyStream.add(history);
    } catch (e) {
      if (kDebugMode) print('Error saving notification to history: $e');
    }
  }

  /// Load notification history from SharedPreferences
  Future<void> _loadNotificationHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList =
          prefs.getStringList(_notificationHistoryKey) ?? [];

      _notifications.clear();
      for (final jsonString in jsonList.reversed) {
        try {
          final json = jsonDecode(jsonString) as Map<String, dynamic>;
          _notifications.add(AppNotification.fromJson(json));
        } catch (e) {
          if (kDebugMode) print('Error parsing notification: $e');
        }
      }
    } catch (e) {
      if (kDebugMode) print('Error loading notification history: $e');
    }
  }

  /// Load notification history synchronously (for internal use)
  List<AppNotification> _loadNotificationHistorySync() {
    return List<AppNotification>.from(_notifications);
  }

  /// Get all notifications
  List<AppNotification> getNotifications() {
    return List<AppNotification>.from(_notifications);
  }

  /// Get recent notifications (last n items)
  List<AppNotification> getRecentNotifications({int limit = 10}) {
    return List<AppNotification>.from(
      _notifications.length > limit
          ? _notifications.sublist(_notifications.length - limit)
          : _notifications,
    );
  }

  /// Get notifications by type
  List<AppNotification> getNotificationsByType(NotificationType type) {
    return _notifications
        .where((notification) => notification.type == type)
        .toList();
  }

  /// Clear all notifications
  Future<void> clearAll() async {
    _notifications.clear();
    await _flutterLocalNotificationsPlugin.cancelAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_notificationHistoryKey);
    _historyStream.add([]);
    if (kDebugMode) print('All notifications cleared');
  }

  /// Clear notifications by type
  Future<void> clearByType(NotificationType type) async {
    _notifications.removeWhere((n) => n.type == type);
    _historyStream.add(_notifications);
    await _saveNotificationsToPrefs();
  }

  /// Save current notifications to SharedPreferences
  Future<void> _saveNotificationsToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList =
          _notifications.map((n) => jsonEncode(n.toJson())).toList();
      await prefs.setStringList(_notificationHistoryKey, jsonList);
    } catch (e) {
      if (kDebugMode) print('Error saving notifications: $e');
    }
  }

  /// Get stream of notifications for real-time updates
  Stream<AppNotification> get notificationStream => _notificationStream.stream;

  /// Get stream of notification history for real-time updates
  Stream<List<AppNotification>> get historyStream => _historyStream.stream;

  /// Dispose the service
  void dispose() {
    _notificationStream.close();
    _historyStream.close();
  }
}
