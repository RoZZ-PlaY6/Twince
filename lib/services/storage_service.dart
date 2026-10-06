import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/task.dart';
import '../models/recurring_task.dart';
import 'notification_service.dart';
import 'alarm_service.dart';

/// The sole writer for tasks, keeping Hive and scheduled alarms in sync.
class StorageService extends ChangeNotifier {
  StorageService._(
    this._box,
    this._recurringBox,
    this._notifications,
    this._alarms,
    this.onTaskUpdatedCallback,
    this.onTaskDeletedCallback,
    this.onTaskCompletedCallback,
  );

  final Box<Task> _box;
  final Box<RecurringTask> _recurringBox;
  final NotificationService? _notifications;
  final AlarmService? _alarms;
  final void Function(Task)? onTaskUpdatedCallback;
  final void Function(String)? onTaskDeletedCallback;
  final void Function(String)? onTaskCompletedCallback;
  bool _generating = false;

  static Future<StorageService> initialize(
    NotificationService? notifications, {
    AlarmService? alarms,
    void Function(Task)? onTaskUpdated,
    void Function(String)? onTaskDeleted,
    void Function(String)? onTaskCompleted,
  }) async {
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(TaskAdapter());
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(RecurringTaskAdapter());
    }
    Box<Task> box;
    try {
      box = await Hive.openBox<Task>('tasks');
    } catch (error) {
      if (!kIsWeb) rethrow;
      // An incompatible IndexedDB box cannot be deserialized. Remove only
      // this task box, then open a fresh one with the current adapter.
      debugPrint('Recovering unreadable Twince task box: $error');
      await Hive.deleteBoxFromDisk('tasks');
      box = await Hive.openBox<Task>('tasks');
    }
    Box<RecurringTask> recurringBox;
    try {
      recurringBox = await Hive.openBox<RecurringTask>('recurring_tasks');
    } catch (error) {
      if (!kIsWeb) rethrow;
      debugPrint('Recovering unreadable Twince recurring box: $error');
      await Hive.deleteBoxFromDisk('recurring_tasks');
      recurringBox = await Hive.openBox<RecurringTask>('recurring_tasks');
    }
    final service = StorageService._(
      box,
      recurringBox,
      notifications,
      alarms,
      onTaskUpdated,
      onTaskDeleted,
      onTaskCompleted,
    );
    await service.generateRecurringInstances();
    return service;
  }

  List<RecurringTask> getRecurringTasks() => _recurringBox.values.toList();

  RecurringTask? getRecurringTaskById(String id) => _recurringBox.get(id);

  Future<void> addRecurringTask(RecurringTask definition) async {
    if (_recurringBox.containsKey(definition.id)) {
      throw StateError('Recurring task already exists');
    }
    await _recurringBox.put(definition.id, definition);
    await generateRecurringInstances();
  }

  /// Updates an existing recurring task definition and regenerates instances
  Future<void> updateRecurringTask(RecurringTask definition) async {
    if (!_recurringBox.containsKey(definition.id)) {
      throw StateError('Recurring task not found');
    }
    await _recurringBox.put(definition.id, definition);
    await _propagateRecurringDefinition(definition);
    await generateRecurringInstances();
  }

  Future<void> _propagateRecurringDefinition(RecurringTask definition) async {
    final now = DateTime.now();
    final occurrences = getAllTasks().where((task) =>
        task.recurringDefinitionId == definition.id &&
        task.status == TaskStatus.pending &&
        task.startTime.isAfter(now));
    for (final existing in occurrences) {
      if (!definition.weekdays.contains(existing.targetDate.weekday)) {
        await deleteTask(existing.id);
        continue;
      }
      final generated = definition.occurrenceOn(existing.targetDate);
      await updateTask(existing.copyWith(
        title: generated.title,
        description: generated.description,
        category: generated.category,
        isTimeBound: generated.isTimeBound,
        targetDate: generated.targetDate,
        startTime: generated.startTime,
        endTime: generated.endTime,
        reminderIntervalMinutes: generated.reminderIntervalMinutes,
        customNotificationMessage: generated.customNotificationMessage,
        clearCustomNotificationMessage:
            generated.customNotificationMessage == null,
        notificationSoundId: generated.notificationSoundId,
        customSystemSoundUri: generated.customSystemSoundUri,
        clearCustomSystemSoundUri: generated.customSystemSoundUri == null,
        notificationTimerOptions: generated.notificationTimerOptions,
        isAlarm: generated.isAlarm,
        alarmSoundType: generated.alarmSoundType,
        alarmSoundId: generated.alarmSoundId,
        alarmSoundUri: generated.alarmSoundUri,
        clearAlarmSoundUri: generated.alarmSoundUri == null,
      ));
    }
  }

  /// Maintains a rolling week; missed dates are backfilled on the next launch.
  Future<void> generateRecurringInstances({DateTime? now}) async {
    if (_generating) return;
    _generating = true;
    try {
      final today = now ?? DateTime.now();
      final horizon = DateTime(today.year, today.month, today.day + 7);
      final existingOccurrences = <String>{
        for (final task in _box.values)
          if (task.recurringDefinitionId != null)
            '${task.recurringDefinitionId}:${task.targetDate.year}-${task.targetDate.month}-${task.targetDate.day}',
      };
      for (final definition in getRecurringTasks()) {
        final first = DateTime(definition.firstDate.year,
            definition.firstDate.month, definition.firstDate.day);
        final created = DateTime(definition.createdAt.year,
            definition.createdAt.month, definition.createdAt.day);
        final through = definition.generatedThrough;
        var day = through == null
            ? (first.isAfter(created) ? first : created)
            : DateTime(through.year, through.month, through.day + 1);
        if (day.isBefore(first)) day = first;
        for (;
            !day.isAfter(horizon);
            day = DateTime(day.year, day.month, day.day + 1)) {
          if (!definition.weekdays.contains(day.weekday)) continue;
          final key = '${definition.id}:${day.year}-${day.month}-${day.day}';
          if (existingOccurrences.add(key)) {
            await addTask(definition.occurrenceOn(day));
          }
        }
        if (through == null || through.isBefore(horizon)) {
          await _recurringBox.put(
              definition.id, definition.copyWithGeneratedThrough(horizon));
        }
      }
    } finally {
      _generating = false;
    }
  }

  /// Schedules or reschedules reminders for a task
  Future<void> _scheduleTaskReminders(Task task) async {
    debugPrint(
        'StorageService: Scheduling reminders for "${task.title}" (${task.id})');
    if (!kIsWeb) {
      await _notifications?.scheduleTask(task);
    } else {
      await _notifications?.scheduleTask(task);
    }
    if (task.isAlarm &&
        task.status == TaskStatus.pending &&
        task.startTime.isAfter(DateTime.now())) {
      await _alarms?.schedule(task);
    } else {
      await _alarms?.cancel(task.id);
    }
  }

  /// Cancels all reminders for a task
  Future<void> _cancelTaskReminders(String taskId) async {
    debugPrint('StorageService: Cancelling reminders for task $taskId');
    if (!kIsWeb) {
      await _notifications?.cancelTask(taskId);
    } else {
      await _notifications?.cancelTask(taskId);
    }
    await _alarms?.cancel(taskId);
  }

  List<Task> getAllTasks() {
    final tasks = _box.values.toList();
    tasks.sort((a, b) => a.startTime.compareTo(b.startTime));
    return tasks;
  }

  Future<void> addTask(Task task) async {
    if (_box.containsKey(task.id)) throw StateError('Task already exists');
    final expired = task.isTimeBound &&
        task.status == TaskStatus.pending &&
        DateTime.now().isAfter(task.endTime);
    final saved = expired ? task.copyWith(status: TaskStatus.failed) : task;
    await _box.put(saved.id, saved);
    notifyListeners();
    await _scheduleTaskReminders(saved);
    onTaskUpdatedCallback?.call(saved);
  }

  Future<void> updateTask(Task task) async {
    if (!_box.containsKey(task.id)) throw StateError('Task not found');
    final expired = task.isTimeBound &&
        task.status == TaskStatus.pending &&
        DateTime.now().isAfter(task.endTime);
    final saved = expired ? task.copyWith(status: TaskStatus.failed) : task;
    await _box.put(saved.id, saved);
    notifyListeners();
    // Always reschedule to pick up any changes (interval, message, times)
    await _scheduleTaskReminders(saved);
    onTaskUpdatedCallback?.call(saved);
  }

  /// Reopens a failed task only with a new, future window.
  Future<void> retryTask(Task task) async {
    final existing = _box.get(task.id);
    if (existing == null || existing.status != TaskStatus.failed) {
      throw StateError('Only failed tasks can be retried');
    }
    if (!task.isTimeBound ||
        !task.startTime.isAfter(DateTime.now()) ||
        !task.endTime.isAfter(task.startTime)) {
      throw ArgumentError('Choose a future start and a later end time');
    }
    await updateTask(task.copyWith(
      status: TaskStatus.pending,
      clearCompletedAt: true,
    ));
  }

  Future<void> deleteTask(String id) async {
    await _cancelTaskReminders(id);
    await _box.delete(id);
    notifyListeners();
    onTaskDeletedCallback?.call(id);
  }

  Future<void> toggleTaskCompleted(String id) async {
    final task = _box.get(id);
    if (task == null || task.status == TaskStatus.failed) return;
    if (task.status == TaskStatus.pending &&
        task.isTimeBound &&
        DateTime.now().isAfter(task.endTime)) {
      await markTaskFailed(id);
      return;
    }
    final completed = task.status != TaskStatus.completed;
    final next = task.copyWith(
      status: completed ? TaskStatus.completed : TaskStatus.pending,
      completedAt: completed ? DateTime.now() : null,
      clearCompletedAt: !completed,
    );
    // A reopened expired task immediately fails.
    if (!completed &&
        next.isTimeBound &&
        DateTime.now().isAfter(next.endTime)) {
      await markTaskFailed(id);
      return;
    }
    await updateTask(next);
    if (completed) {
      onTaskCompletedCallback?.call(id);
    }
  }

  Future<void> markTaskFailed(String id) async {
    final task = _box.get(id);
    if (task == null ||
        task.status != TaskStatus.pending ||
        !task.isTimeBound ||
        !DateTime.now().isAfter(task.endTime)) {
      return;
    }
    await _box.put(id, task.copyWith(status: TaskStatus.failed));
    notifyListeners();
    await _cancelTaskReminders(id);
    onTaskCompletedCallback
        ?.call(id); // Treat failed same as completed for cleanup
  }

  /// Reconciles all task reminders - call on app startup and resume
  Future<void> reconcile() async {
    debugPrint('StorageService: Reconciling all task reminders');
    final now = DateTime.now();
    for (final task in getAllTasks()) {
      if (task.status == TaskStatus.pending &&
          task.isTimeBound &&
          now.isAfter(task.endTime)) {
        await markTaskFailed(task.id);
      } else if (task.status == TaskStatus.pending) {
        await _scheduleTaskReminders(task);
        // If task is currently in active window, ensure next interval is scheduled
        if (task.isTimeBound &&
            !now.isBefore(task.startTime) &&
            now.isBefore(task.endTime)) {
          await _notifications?.scheduleImmediateIfActive(task);
        }
      } else {
        await _cancelTaskReminders(task.id);
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
    _box.close();
    _recurringBox.close();
    _notifications?.dispose();
  }

  /// Clears all tasks and recurring tasks from storage
  Future<void> clearAllData() async {
    for (final task in _box.values) {
      await _cancelTaskReminders(task.id);
    }
    await _box.clear();
    await _recurringBox.clear();
    notifyListeners();
  }
}
