import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Schedules the OS-level check-in reminders that fire while the app is in
/// the background. The in-app prompt works without this.
abstract interface class ReminderScheduler {
  /// Sets up the plugin. [onTap] runs when a reminder is tapped, including
  /// when the tap launched the app.
  Future<void> init({required VoidCallback onTap});

  /// Asks for permission to post notifications. True if allowed.
  Future<bool> requestPermission();

  /// Whether reminders can fire at exact times rather than roughly.
  Future<bool> canBeExact();

  /// Opens the system screen to allow exact timing.
  Future<void> requestExact();

  /// Replaces any scheduled reminders with ones at [times].
  Future<void> schedule(List<DateTime> times);

  Future<void> cancelAll();
}

/// Used on the web and in tests, where only the in-app prompt runs.
class NoopReminderScheduler implements ReminderScheduler {
  const NoopReminderScheduler();

  @override
  Future<void> init({required VoidCallback onTap}) async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<bool> canBeExact() async => true;

  @override
  Future<void> requestExact() async {}

  @override
  Future<void> schedule(List<DateTime> times) async {}

  @override
  Future<void> cancelAll() async {}
}

class LocalNotificationScheduler implements ReminderScheduler {
  final _plugin = FlutterLocalNotificationsPlugin();

  static const _firstId = 7000;

  /// Upper bound on reminders queued for one session (15 min × 24 h).
  static const _maxScheduled = 96;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'check_in',
      'Check-ins',
      channelDescription: 'Reminders to scan your mental state while trading',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  @override
  Future<void> init({required VoidCallback onTap}) async {
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (_) => onTap(),
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) onTap();
  }

  @override
  Future<bool> requestPermission() async =>
      await _android?.requestNotificationsPermission() ?? true;

  @override
  Future<bool> canBeExact() async =>
      await _android?.canScheduleExactNotifications() ?? false;

  @override
  Future<void> requestExact() async => _android?.requestExactAlarmsPermission();

  @override
  Future<void> schedule(List<DateTime> times) async {
    await cancelAll();
    final exact = await canBeExact();
    for (final (i, t) in times.take(_maxScheduled).indexed) {
      await _plugin.zonedSchedule(
        id: _firstId + i,
        scheduledDate: tz.TZDateTime.from(t.toUtc(), tz.UTC),
        notificationDetails: _details,
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        title: 'Check-in',
        body: 'How are you feeling? Any signals from your maps?',
      );
    }
  }

  @override
  Future<void> cancelAll() async {
    for (var i = 0; i < _maxScheduled; i++) {
      await _plugin.cancel(id: _firstId + i);
    }
  }
}

ReminderScheduler platformReminderScheduler() =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android
        ? LocalNotificationScheduler()
        : const NoopReminderScheduler();
