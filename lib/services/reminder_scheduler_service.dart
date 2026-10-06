import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../models/task.dart';
import 'notification_service.dart';
import 'storage_service.dart';

/// Foreground periodic reminder scheduler that fires interval notifications
/// while the app is running. This works around OS restrictions on frequent
/// background alarms (e.g., Android's 15-minute minimum for AlarmManager).
class ReminderSchedulerService with WidgetsBindingObserver {
  ReminderSchedulerService({
    required StorageService storage,
    required NotificationService notifications,
  })  : _storage = storage,
        _notifications = notifications;

  final StorageService _storage;
  final NotificationService _notifications;

  Timer? _ticker;
  static const Duration _checkInterval = Duration(seconds: 15);

  // Track last notification time per task to enforce interval
  final Map<String, DateTime> _lastNotified = {};

  /// Initialize and start the periodic ticker
  void start() {
    WidgetsBinding.instance.addObserver(this);
    _ticker = Timer.periodic(_checkInterval, (_) => _checkActiveTasks());
    debugPrint(
        '[Twince-Reminder] Scheduler started, checking every ${_checkInterval.inSeconds}s');
    // Run initial check immediately
    _checkActiveTasks();
  }

  /// Periodic check: find all active tasks and fire due reminders
  Future<void> _checkActiveTasks() async {
    final now = DateTime.now();
    final tasks = _storage.getAllTasks();
    int activeCount = 0;

    for (final task in tasks) {
      if (!task.isTimeBound ||
          task.status != TaskStatus.pending ||
          task.reminderIntervalMinutes < 1) {
        continue;
      }

      // Check if task is in active window (handles overnight via endTime comparison)
      final isActive =
          !now.isBefore(task.startTime) && now.isBefore(task.endTime);
      if (!isActive) {
        // Task not active - clean up last notified time
        if (_lastNotified.containsKey(task.id)) {
          debugPrint(
              '[Twince-Reminder] Task "${task.title}" (${task.id}) no longer active, clearing lastNotified');
          _lastNotified.remove(task.id);
        }
        continue;
      }

      activeCount++;

      // Check if interval has elapsed since last notification
      final lastNotified = _lastNotified[task.id];
      final interval = Duration(minutes: task.reminderIntervalMinutes);
      bool shouldNotify = false;

      if (lastNotified == null) {
        // First notification in this active window - fire at first interval after startTime
        final firstInterval =
            _getNextIntervalAfter(task.startTime, interval, now);
        if (!firstInterval.isAfter(now)) {
          shouldNotify = true;
        }
      } else if (now.difference(lastNotified) >= interval) {
        shouldNotify = true;
      }

      if (shouldNotify) {
        debugPrint(
            '[Twince-Reminder] FIRING notification for "${task.title}" (${task.id}) '
            'now=$now lastNotified=${_lastNotified[task.id]?.toString() ?? "never"} interval=${interval.inMinutes}min');
        await _fireNotification(task);
        _lastNotified[task.id] = now;
      } else {
        final timeSinceLast =
            lastNotified != null ? now.difference(lastNotified) : null;
        final timeToNext = timeSinceLast != null
            ? interval - timeSinceLast
            : _getNextIntervalAfter(task.startTime, interval, now)
                .difference(now);
        debugPrint('[Twince-Reminder] Task "${task.title}" active - '
            'timeSinceLast=${timeSinceLast?.inSeconds ?? "N/A"}s '
            'timeToNext=${timeToNext.inSeconds}s');
      }
    }

    debugPrint(
        '[Twince-Reminder] Check complete: $activeCount active task(s), ${_lastNotified.length} tracked');
  }

  /// Calculate the next interval boundary after [startTime] using [interval]
  DateTime _getNextIntervalAfter(
      DateTime startTime, Duration interval, DateTime now) {
    var next = startTime;
    while (next.isBefore(now)) {
      next = next.add(interval);
    }
    return next;
  }

  /// Fire a notification for the given task
  Future<void> _fireNotification(Task task) async {
    final title = 'Task In Progress: ${task.title}';
    final body = task.hasCustomNotificationMessage
        ? task.customNotificationMessage!.trim()
        : 'Task "${task.title}" is in progress. Please attend to it.';

    if (!kIsWeb) {
      await _notifications.showTest(title, body);
    } else {
      await _notifications.showTest(title, body);
    }
  }

  /// Call when app resumes to catch up on missed intervals
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('[Twince-Reminder] App resumed, running immediate check');
      _checkActiveTasks();
    }
  }

  /// Clean up tracking for completed/deleted tasks
  void onTaskCompletedOrDeleted(String taskId) {
    if (_lastNotified.remove(taskId) != null) {
      debugPrint('[Twince-Reminder] Cleared tracking for task $taskId');
    }
  }

  /// Update tracking when task interval/message changes
  void onTaskUpdated(Task task) {
    // If task is currently active, we keep tracking but next check will use new interval
    debugPrint(
        '[Twince-Reminder] Task "${task.title}" updated, interval=${task.reminderIntervalMinutes}min');
  }

  void dispose() {
    _ticker?.cancel();
    _ticker = null;
    _lastNotified.clear();
    WidgetsBinding.instance.removeObserver(this);
    debugPrint('[Twince-Reminder] Scheduler disposed');
  }
}
