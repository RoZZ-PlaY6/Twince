import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../models/task.dart';
import 'browser_notification.dart';

/// Helper class for scheduled notifications
class _ScheduledNotification {
  final DateTime time;
  final String type; // '5x', 'everyHour', 'thirtyMinutes', etc.
  final int?
      minuteOffset; // Negative minutes from end (e.g., -5 for 5 minutes before end)

  _ScheduledNotification({
    required this.time,
    required this.type,
    this.minuteOffset,
  });
}

/// Schedules interval notifications during active task time windows.
/// Supports Android (via flutter_local_notifications) and Web (via browser notifications).
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _exactAlarmsAllowed = false;
  bool _initialized = false;
  tz.Location? _localLocation;
  static const String _channelId = 'twince_reminders';
  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      'Task reminders',
      channelDescription: 'Reminders during active task time windows',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  // Web-specific timer for recurring notifications when app is in foreground
  final Map<String, Timer> _webTaskTimers = {};

  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone - use local timezone
    _localLocation = tz.local;

    // Initialize flutter_local_notifications (Android/Windows)
    if (!kIsWeb) {
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('notification_icon'),
        ),
      );
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
      _exactAlarmsAllowed =
          await android?.requestExactAlarmsPermission() ?? false;
      debugPrint(
          'NotificationService: Android initialized, exact alarms: $_exactAlarmsAllowed');
    } else {
      debugPrint('NotificationService: Web platform detected');
    }

    _initialized = true;
  }

  /// Clears only alarms belonging to this task, including older schedules.
  Future<void> cancelTask(String taskId) async {
    if (!kIsWeb) {
      final pending = await _plugin.pendingNotificationRequests();
      for (final request in pending) {
        if (request.payload == taskId) {
          await _plugin.cancel(request.id);
          debugPrint(
              'NotificationService: Cancelled notification $request.id for task $taskId');
        }
      }
    } else {
      // Cancel web timer for this task
      _webTaskTimers[taskId]?.cancel();
      _webTaskTimers.remove(taskId);
      debugPrint('NotificationService: Cancelled web timer for task $taskId');
    }
  }

  /// Shows an immediate, user-triggered notification (no exact alarm needed).
  Future<bool> showTest(String title, String body) async {
    if (!kIsWeb) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final allowed = await android?.requestNotificationsPermission();
      if (allowed == false) return false;
      await _plugin.show(
        DateTime.now().microsecondsSinceEpoch & 0x7fffffff,
        title,
        body,
        _details,
      );
      return true;
    } else {
      return showBrowserNotification(title, body);
    }
  }

  /// Schedules notifications for the active task window based on task's notificationTimerOptions.
  /// Supports: everyHour, 30m, 15m, 10m, 5m, 5x (last 5 minutes every minute)
  Future<void> scheduleTask(Task task) async {
    debugPrint(
        'NotificationService: scheduleTask called for "${task.title}" (${task.id})');
    debugPrint('  startTime: ${task.startTime}, endTime: ${task.endTime}');
    debugPrint('  isTimeBound: ${task.isTimeBound}, status: ${task.status}');
    debugPrint(
        '  notificationTimerOptions: ${task.notificationTimerOptions.map((e) => e.name).toList()}');

    await cancelTask(task.id);

    if (!task.isTimeBound ||
        task.status != TaskStatus.pending ||
        task.notificationTimerOptions.isEmpty) {
      debugPrint(
          'NotificationService: Skipping - not timeBound, not pending, or no timer options');
      return;
    }

    final now = DateTime.now();
    if (!task.endTime.isAfter(now)) {
      debugPrint('NotificationService: Skipping - task endTime is in the past');
      return;
    }

    // Calculate all notification times based on the selected options
    final notificationTimes = _calculateNotificationTimes(task, now);

    if (notificationTimes.isEmpty) {
      debugPrint(
          'NotificationService: No valid notification times to schedule');
      return;
    }

    if (!kIsWeb) {
      await _scheduleNotificationsAndroid(task, notificationTimes);
    } else {
      await _scheduleNotificationsWeb(task, notificationTimes);
    }
  }

  /// Calculate all unique notification times based on the selected timer options
  List<_ScheduledNotification> _calculateNotificationTimes(
      Task task, DateTime now) {
    final times = <_ScheduledNotification>[];
    final duration = task.endTime.difference(task.startTime);
    final options = task.notificationTimerOptions;

    // Helper to add a notification time if it's valid (after now, before endTime)
    void addIfValid(DateTime time, String type, {int? minuteOffset}) {
      if (time.isAfter(now) && time.isBefore(task.endTime)) {
        times.add(_ScheduledNotification(
          time: time,
          type: type,
          minuteOffset: minuteOffset,
        ));
      }
    }

    // 5x option: one notification every minute in the last 5 minutes
    if (options.contains(NotificationTimerOption.fiveTimes)) {
      for (int i = 5; i >= 1; i--) {
        final time = task.endTime.subtract(Duration(minutes: i));
        addIfValid(time, '5x', minuteOffset: -i);
      }
    }

    // Fixed minute options
    for (final option in options) {
      final minutes = option.minutesBeforeEnd;
      if (minutes != null) {
        final time = task.endTime.subtract(Duration(minutes: minutes));
        addIfValid(time, option.name, minuteOffset: -minutes);
      }
    }

    // Every hour option
    if (options.contains(NotificationTimerOption.everyHour)) {
      // Schedule for each full hour from start to end
      var hourTime = DateTime(
        task.startTime.year,
        task.startTime.month,
        task.startTime.day,
        task.startTime.hour,
        0,
        0,
      );

      // If start time is not on the hour, move to next hour
      if (task.startTime.minute > 0 || task.startTime.second > 0) {
        hourTime = hourTime.add(const Duration(hours: 1));
      }

      while (hourTime.isBefore(task.endTime)) {
        addIfValid(hourTime, 'everyHour');
        hourTime = hourTime.add(const Duration(hours: 1));
      }
    }

    // Sort by time and remove duplicates (same time from different options)
    times.sort((a, b) => a.time.compareTo(b.time));

    // Remove duplicates (same time within 1 second)
    final uniqueTimes = <_ScheduledNotification>[];
    for (final t in times) {
      if (uniqueTimes.isEmpty ||
          t.time.difference(uniqueTimes.last.time).inSeconds > 1) {
        uniqueTimes.add(t);
      }
    }

    return uniqueTimes;
  }

  /// Android/Windows: Schedule using flutter_local_notifications with exact alarms
  Future<void> _scheduleNotificationsAndroid(
      Task task, List<_ScheduledNotification> times) async {
    if (!_exactAlarmsAllowed) {
      debugPrint(
          'NotificationService: Exact alarms not allowed, skipping Android scheduling');
      return;
    }

    int scheduledCount = 0;
    for (int i = 0; i < times.length; i++) {
      final notification = times[i];
      try {
        final tzWhen = tz.TZDateTime.from(notification.time, _localLocation!);
        final id = _notificationId(task.id, i);

        String body;
        if (notification.type == '5x' && notification.minuteOffset != null) {
          body =
              '${(-notification.minuteOffset!)} minutes remaining until the task ends.';
        } else if (notification.minuteOffset != null) {
          body =
              '${(-notification.minuteOffset!)} minutes remaining until the task ends.';
        } else if (notification.type == 'everyHour') {
          final hoursRemaining =
              task.endTime.difference(notification.time).inHours;
          body =
              '$hoursRemaining hour${hoursRemaining != 1 ? 's' : ''} remaining until the task ends.';
        } else {
          body = _getNotificationBody(task);
        }

        await _plugin.zonedSchedule(
          id,
          'Task Reminder: ${task.title}',
          body,
          tzWhen,
          _details,
          payload: task.id,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
        scheduledCount++;
        debugPrint(
            'NotificationService: Scheduled ${notification.type} notification for "${task.title}" at ${notification.time}');
      } catch (e) {
        debugPrint('NotificationService: Failed to schedule notification: $e');
      }
    }
    debugPrint(
        'NotificationService: Scheduled $scheduledCount notifications for "${task.title}"');
  }

  /// Web: Use Timer-based scheduling for foreground notifications
  Future<void> _scheduleNotificationsWeb(
      Task task, List<_ScheduledNotification> times) async {
    final now = DateTime.now();

    // Cancel any existing timer for this task
    _webTaskTimers[task.id]?.cancel();

    // Schedule each notification as a separate timer
    for (int i = 0; i < times.length; i++) {
      final notification = times[i];
      final delay = notification.time.difference(now);

      if (delay.isNegative) continue;

      final timer = Timer(delay, () async {
        String body;
        if (notification.type == '5x' && notification.minuteOffset != null) {
          body =
              '${(-notification.minuteOffset!)} minutes remaining until the task ends.';
        } else if (notification.minuteOffset != null) {
          body =
              '${(-notification.minuteOffset!)} minutes remaining until the task ends.';
        } else if (notification.type == 'everyHour') {
          final hoursRemaining =
              task.endTime.difference(notification.time).inHours;
          body =
              '$hoursRemaining hour${hoursRemaining != 1 ? 's' : ''} remaining until the task ends.';
        } else {
          body = _getNotificationBody(task);
        }

        await showBrowserNotification(
          'Task Reminder: ${task.title}',
          body,
        );

        debugPrint(
            'NotificationService: Web - Fired ${notification.type} notification for "${task.title}"');
      });

      _webTaskTimers['${task.id}:${notification.time.millisecondsSinceEpoch}'] =
          timer;
    }

    debugPrint(
        'NotificationService: Web - Scheduled ${times.length} timers for "${task.title}"');
  }

  void _scheduleWebTimer(Task task, DateTime now) {
    // Cancel existing timer
    _webTaskTimers[task.id]?.cancel();

    // Calculate next interval
    var nextInterval = task.startTime;
    while (nextInterval.isBefore(now)) {
      nextInterval =
          nextInterval.add(Duration(minutes: task.reminderIntervalMinutes));
    }

    if (nextInterval.isBefore(task.endTime)) {
      final delay = nextInterval.difference(now);
      debugPrint(
          'NotificationService: Web - next reminder for "${task.title}" in ${delay.inSeconds}s at $nextInterval');

      _webTaskTimers[task.id] = Timer(delay, () async {
        // Show notification
        await showBrowserNotification(
          'Task In Progress: ${task.title}',
          _getNotificationBody(task),
        );

        // Schedule next interval if still within endTime
        final nextNow = DateTime.now();
        if (!nextNow.isBefore(task.startTime) &&
            nextNow.isBefore(task.endTime)) {
          _scheduleWebTimer(task, nextNow);
        } else {
          debugPrint(
              'NotificationService: Web - task window ended, stopping timers for "${task.title}"');
          _webTaskTimers.remove(task.id);
        }
      });
    } else {
      debugPrint(
          'NotificationService: Web - no more intervals within window for "${task.title}"');
    }
  }

  /// Schedules immediate notifications if the task window is currently active.
  /// This handles the case where the app starts and a task is already in progress.
  Future<void> scheduleImmediateIfActive(Task task) async {
    debugPrint(
        'NotificationService: scheduleImmediateIfActive for "${task.title}"');

    if (!task.isTimeBound ||
        task.status != TaskStatus.pending ||
        task.notificationTimerOptions.isEmpty) {
      return;
    }

    final now = DateTime.now();
    if (now.isBefore(task.startTime) || now.isAfter(task.endTime)) {
      debugPrint('NotificationService: Not in active window');
      return; // Not in active window
    }

    // Calculate the next notification time based on the selected options
    final notificationTimes = _calculateNotificationTimes(task, now);

    // Find the next notification time after now
    final futureNotifications =
        notificationTimes.where((n) => n.time.isAfter(now)).toList();
    if (futureNotifications.isEmpty) {
      debugPrint('NotificationService: No future notifications to schedule');
      return;
    }

    // Sort by time and take the earliest one
    futureNotifications.sort((a, b) => a.time.compareTo(b.time));
    final nextNotification = futureNotifications.first;

    if (!kIsWeb) {
      if (!_exactAlarmsAllowed) return;
      final id = _notificationId(task.id, 0);
      try {
        final tzWhen =
            tz.TZDateTime.from(nextNotification.time, _localLocation!);

        String body;
        if (nextNotification.type == '5x' &&
            nextNotification.minuteOffset != null) {
          body =
              '${(-nextNotification.minuteOffset!)} minutes remaining until the task ends.';
        } else if (nextNotification.minuteOffset != null) {
          body =
              '${(-nextNotification.minuteOffset!)} minutes remaining until the task ends.';
        } else if (nextNotification.type == 'everyHour') {
          final hoursRemaining =
              task.endTime.difference(nextNotification.time).inHours;
          body =
              '$hoursRemaining hour${hoursRemaining != 1 ? 's' : ''} remaining until the task ends.';
        } else {
          body = _getNotificationBody(task);
        }

        await _plugin.zonedSchedule(
          id,
          'Task Reminder: ${task.title}',
          body,
          tzWhen,
          _details,
          payload: task.id,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
        debugPrint(
            'NotificationService: Scheduled immediate active reminder for "${task.title}" at ${nextNotification.time}');
      } catch (e) {
        debugPrint(
            'NotificationService: Failed to schedule immediate reminder: $e');
      }
    } else {
      // For web, schedule a timer for the next notification
      final delay = nextNotification.time.difference(DateTime.now());
      if (delay.isNegative) return;

      _webTaskTimers['${task.id}:immediate'] = Timer(delay, () async {
        String body;
        if (nextNotification.type == '5x' &&
            nextNotification.minuteOffset != null) {
          body =
              '${(-nextNotification.minuteOffset!)} minutes remaining until the task ends.';
        } else if (nextNotification.minuteOffset != null) {
          body =
              '${(-nextNotification.minuteOffset!)} minutes remaining until the task ends.';
        } else if (nextNotification.type == 'everyHour') {
          final hoursRemaining =
              task.endTime.difference(nextNotification.time).inHours;
          body =
              '$hoursRemaining hour${hoursRemaining != 1 ? 's' : ''} remaining until the task ends.';
        } else {
          body = _getNotificationBody(task);
        }

        await showBrowserNotification(
          'Task Reminder: ${task.title}',
          body,
        );
        debugPrint(
            'NotificationService: Web - Fired immediate notification for "${task.title}"');
      });
    }
  }

  String _getNotificationBody(Task task) {
    if (task.hasCustomNotificationMessage) {
      return task.customNotificationMessage!.trim();
    }
    return 'Task "${task.title}" is in progress. Please attend to it.';
  }

  int _notificationId(String id, int index) {
    var hash = 0x811c9dc5;
    for (final unit in '$id:$index'.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
    }
    return hash & 0x7fffffff;
  }

  void dispose() {
    if (kIsWeb) {
      for (final timer in _webTaskTimers.values) {
        timer.cancel();
      }
      _webTaskTimers.clear();
    }
  }
}
