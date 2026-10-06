import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

enum TaskStatus { pending, completed, failed }

enum TaskCategory { daily, important, etc }

enum AlarmSoundType { system, builtIn, customFile }

/// Notification timer options for task reminders.
enum NotificationTimerOption {
  /// Every full hour before task ends (only available for tasks > 1 hour)
  everyHour,

  /// 30 minutes before task ends
  thirtyMinutes,

  /// 15 minutes before task ends
  fifteenMinutes,

  /// 10 minutes before task ends
  tenMinutes,

  /// 5 minutes before task ends
  fiveMinutes,

  /// 5x - one notification per minute in the last 5 minutes
  fiveTimes,
}

/// Extension for display labels and durations
extension NotificationTimerOptionX on NotificationTimerOption {
  String get label => switch (this) {
        NotificationTimerOption.everyHour => 'Every hour',
        NotificationTimerOption.thirtyMinutes => '30 minutes before the end',
        NotificationTimerOption.fifteenMinutes => '15 minutes before the end',
        NotificationTimerOption.tenMinutes => '10 minutes before the end',
        NotificationTimerOption.fiveMinutes => '5 minutes before the end',
        NotificationTimerOption.fiveTimes =>
          '5x (last 5 minutes, every minute)',
      };

  String get description => switch (this) {
        NotificationTimerOption.everyHour =>
          'Notifies every full hour before the task ends (available for tasks > 1 hour)',
        NotificationTimerOption.thirtyMinutes =>
          'Notifies 30 minutes before the task ends',
        NotificationTimerOption.fifteenMinutes =>
          'Notifies 15 minutes before the task ends',
        NotificationTimerOption.tenMinutes =>
          'Notifies 10 minutes before the task ends',
        NotificationTimerOption.fiveMinutes =>
          'Notifies 5 minutes before the task ends',
        NotificationTimerOption.fiveTimes =>
          'Notifies every minute in the last 5 minutes (5, 4, 3, 2, 1 min remaining)',
      };

  /// Returns the minutes before end for fixed options, null for everyHour and fiveTimes
  int? get minutesBeforeEnd => switch (this) {
        NotificationTimerOption.everyHour => null,
        NotificationTimerOption.thirtyMinutes => 30,
        NotificationTimerOption.fifteenMinutes => 15,
        NotificationTimerOption.tenMinutes => 10,
        NotificationTimerOption.fiveMinutes => 5,
        NotificationTimerOption.fiveTimes => null,
      };

  /// Whether this option is available for the given task duration
  bool isAvailableForDuration(Duration duration) => switch (this) {
        NotificationTimerOption.everyHour =>
          duration > const Duration(hours: 1),
        _ => true,
      };
}

extension TaskCategoryX on TaskCategory {
  String get label => switch (this) {
        TaskCategory.daily => 'Daily',
        TaskCategory.important => 'Important',
        TaskCategory.etc => 'ETC',
      };

  static TaskCategory fromString(String value) {
    return TaskCategory.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => TaskCategory.etc,
    );
  }
}

/// A task's time fields are local wall-clock instants on [targetDate].
class Task {
  Task({
    String? id,
    required String title,
    this.description = '',
    this.category = TaskCategory.etc,
    this.status = TaskStatus.pending,
    this.isTimeBound = true,
    required this.targetDate,
    required this.startTime,
    required this.endTime,
    this.reminderIntervalMinutes = 60,
    DateTime? createdAt,
    this.completedAt,
    this.recurringDefinitionId,
    this.customNotificationMessage,
    this.notificationSoundId = 'cyber_pulse',
    this.customSystemSoundUri,
    this.notificationTimerOptions = const {},
    this.isAlarm = false,
    this.alarmSoundType = AlarmSoundType.system,
    this.alarmSoundId = 'cyber_pulse',
    this.alarmSoundUri,
  })  : id = id ?? const Uuid().v4(),
        title = title.trim(),
        createdAt = createdAt ?? DateTime.now() {
    if (this.title.isEmpty) throw ArgumentError('Title is required');
    if (reminderIntervalMinutes < 1) {
      throw ArgumentError('Reminder interval must be positive');
    }
    if (isTimeBound && !endTime.isAfter(startTime)) {
      throw ArgumentError('End time must be after start time');
    }
    if (isTimeBound) {
      final startDay =
          DateTime(targetDate.year, targetDate.month, targetDate.day);
      final endDay = DateTime(endTime.year, endTime.month, endTime.day);
      final nextDay = startDay.add(const Duration(days: 1));
      if (startTime.isBefore(startDay) ||
          startTime.isAfter(startDay.add(const Duration(days: 1)))) {
        throw ArgumentError('Start time must be on the target date');
      }
      if (endDay.isBefore(startDay) || endDay.isAfter(nextDay)) {
        throw ArgumentError(
            'End time must be on the target date or the next day');
      }
    }
  }

  final String id;
  final String title;
  final String description;
  final TaskCategory category;
  final TaskStatus status;
  final bool isTimeBound;
  final DateTime targetDate;
  final DateTime startTime;
  final DateTime endTime;
  final int reminderIntervalMinutes;
  final DateTime createdAt;
  final DateTime? completedAt;

  /// Present only on an independent occurrence generated by a recurrence.
  final String? recurringDefinitionId;

  /// Optional custom notification message. If null/empty, default message is used.
  final String? customNotificationMessage;

  /// Notification sound identifier (e.g., 'cyber_pulse', 'alert_neon', 'system_custom')
  final String notificationSoundId;

  /// Custom system sound URI (for Android system picker selection)
  final String? customSystemSoundUri;

  /// Selected notification timer options for this task.
  final Set<NotificationTimerOption> notificationTimerOptions;

  /// Whether an exact, full-screen alarm should ring at [startTime].
  final bool isAlarm;

  final AlarmSoundType alarmSoundType;
  final String alarmSoundId;
  final String? alarmSoundUri;

  bool get hasCustomNotificationMessage =>
      customNotificationMessage != null &&
      customNotificationMessage!.trim().isNotEmpty;

  Task copyWith({
    String? title,
    String? description,
    TaskCategory? category,
    TaskStatus? status,
    bool? isTimeBound,
    DateTime? targetDate,
    DateTime? startTime,
    DateTime? endTime,
    int? reminderIntervalMinutes,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    String? recurringDefinitionId,
    String? customNotificationMessage,
    bool clearCustomNotificationMessage = false,
    String? notificationSoundId,
    String? customSystemSoundUri,
    bool clearCustomSystemSoundUri = false,
    Set<NotificationTimerOption>? notificationTimerOptions,
    bool? isAlarm,
    AlarmSoundType? alarmSoundType,
    String? alarmSoundId,
    String? alarmSoundUri,
    bool clearAlarmSoundUri = false,
  }) =>
      Task(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        category: category ?? this.category,
        status: status ?? this.status,
        isTimeBound: isTimeBound ?? this.isTimeBound,
        targetDate: targetDate ?? this.targetDate,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        reminderIntervalMinutes:
            reminderIntervalMinutes ?? this.reminderIntervalMinutes,
        createdAt: createdAt,
        completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
        recurringDefinitionId:
            recurringDefinitionId ?? this.recurringDefinitionId,
        customNotificationMessage: clearCustomNotificationMessage
            ? null
            : customNotificationMessage ?? this.customNotificationMessage,
        notificationSoundId: notificationSoundId ?? this.notificationSoundId,
        customSystemSoundUri: clearCustomSystemSoundUri
            ? null
            : customSystemSoundUri ?? this.customSystemSoundUri,
        notificationTimerOptions:
            notificationTimerOptions ?? this.notificationTimerOptions,
        isAlarm: isAlarm ?? this.isAlarm,
        alarmSoundType: alarmSoundType ?? this.alarmSoundType,
        alarmSoundId: alarmSoundId ?? this.alarmSoundId,
        alarmSoundUri:
            clearAlarmSoundUri ? null : alarmSoundUri ?? this.alarmSoundUri,
      );
}

/// Stable, hand-written adapter; no code generation is required.
class TaskAdapter extends TypeAdapter<Task> {
  @override
  final int typeId = 0;

  @override
  Task read(BinaryReader reader) {
    final fields = <int, dynamic>{};
    final count = reader.readByte();
    for (var i = 0; i < count; i++) {
      fields[reader.readByte()] = reader.read();
    }
    // Handle backward compatibility: category was stored as String, now as int (enum index)
    final categoryValue = fields[3];
    TaskCategory category;
    if (categoryValue is int) {
      category = TaskCategory
          .values[categoryValue.clamp(0, TaskCategory.values.length - 1)];
    } else if (categoryValue is String) {
      category = TaskCategoryX.fromString(categoryValue);
    } else {
      category = TaskCategory.etc;
    }
    // Handle backward compatibility: customNotificationMessage is field 13, notificationSoundId is 14, customSystemSoundUri is 15, notificationTimerOptions is 16
    final customMessage = fields[13] as String?;
    final notificationSoundId = fields[14] as String? ?? 'cyber_pulse';
    final customSystemSoundUri = fields[15] as String?;
    final notificationTimerOptions = fields[16] as List?;
    final alarmSoundTypeIndex = fields[18] as int? ?? 0;
    return Task(
      id: fields[0] as String,
      title: fields[1] as String,
      description: fields[2] as String? ?? '',
      category: category,
      status: TaskStatus.values[(fields[4] as int?) ?? 0],
      isTimeBound: fields[5] as bool? ?? true,
      targetDate: fields[6] as DateTime,
      startTime: fields[7] as DateTime,
      endTime: fields[8] as DateTime,
      reminderIntervalMinutes: fields[9] as int? ?? 60,
      createdAt: fields[10] as DateTime,
      completedAt: fields[11] as DateTime?,
      recurringDefinitionId: fields[12] as String?,
      customNotificationMessage: customMessage,
      notificationSoundId: notificationSoundId,
      customSystemSoundUri: customSystemSoundUri,
      notificationTimerOptions: notificationTimerOptions != null
          ? notificationTimerOptions
              .map((e) => NotificationTimerOption.values[e as int])
              .toSet()
          : const {},
      isAlarm: fields[17] as bool? ?? false,
      alarmSoundType: AlarmSoundType.values[
          alarmSoundTypeIndex.clamp(0, AlarmSoundType.values.length - 1)],
      alarmSoundId: fields[19] as String? ?? 'cyber_pulse',
      alarmSoundUri: fields[20] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Task task) {
    writer
      ..writeByte(21)
      ..writeByte(0)
      ..write(task.id)
      ..writeByte(1)
      ..write(task.title)
      ..writeByte(2)
      ..write(task.description)
      ..writeByte(3)
      ..write(task.category.index)
      ..writeByte(4)
      ..write(task.status.index)
      ..writeByte(5)
      ..write(task.isTimeBound)
      ..writeByte(6)
      ..write(task.targetDate)
      ..writeByte(7)
      ..write(task.startTime)
      ..writeByte(8)
      ..write(task.endTime)
      ..writeByte(9)
      ..write(task.reminderIntervalMinutes)
      ..writeByte(10)
      ..write(task.createdAt)
      ..writeByte(11)
      ..write(task.completedAt)
      ..writeByte(12)
      ..write(task.recurringDefinitionId)
      ..writeByte(13)
      ..write(task.customNotificationMessage)
      ..writeByte(14)
      ..write(task.notificationSoundId)
      ..writeByte(15)
      ..write(task.customSystemSoundUri)
      ..writeByte(16)
      ..write(task.notificationTimerOptions.map((e) => e.index).toList())
      ..writeByte(17)
      ..write(task.isAlarm)
      ..writeByte(18)
      ..write(task.alarmSoundType.index)
      ..writeByte(19)
      ..write(task.alarmSoundId)
      ..writeByte(20)
      ..write(task.alarmSoundUri);
  }
}
