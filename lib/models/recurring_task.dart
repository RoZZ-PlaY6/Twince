import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import 'task.dart';

/// A weekly template. Generated [Task] records own their status and edits.
class RecurringTask {
  RecurringTask({
    String? id,
    required String title,
    this.description = '',
    this.category = TaskCategory.etc,
    required List<int> weekdays,
    required this.firstDate,
    required this.startTime,
    required this.endTime,
    this.isTimeBound = true,
    this.reminderIntervalMinutes = 60,
    DateTime? createdAt,
    this.generatedThrough,
    this.customNotificationMessage,
    this.notificationSoundId = 'cyber_pulse',
    this.customSystemSoundUri,
    this.notificationTimerOptions = const {},
  })  : id = id ?? const Uuid().v4(),
        title = title.trim(),
        weekdays = List.unmodifiable(weekdays.toSet().toList()..sort()),
        createdAt = createdAt ?? DateTime.now() {
    if (this.title.isEmpty) throw ArgumentError('Title is required');
    if (this.weekdays.isEmpty ||
        this.weekdays.any((day) => day < 1 || day > 7)) {
      throw ArgumentError(
          'Select at least one weekday (Monday = 1, Sunday = 7)');
    }
    final startSeconds =
        startTime.hour * 3600 + startTime.minute * 60 + startTime.second;
    final endSeconds =
        endTime.hour * 3600 + endTime.minute * 60 + endTime.second;
    if (isTimeBound && endSeconds == startSeconds) {
      throw ArgumentError('End time must differ from start time');
    }
    if (reminderIntervalMinutes < 1) {
      throw ArgumentError('Reminder interval must be positive');
    }
  }

  final String id;
  final String title;
  final String description;
  final TaskCategory category;
  final List<int> weekdays;
  final DateTime firstDate;
  final DateTime startTime;
  final DateTime endTime;
  final bool isTimeBound;
  final int reminderIntervalMinutes;
  final DateTime createdAt;
  final DateTime? generatedThrough;

  /// Optional custom notification message. If null/empty, default message is used.
  final String? customNotificationMessage;

  /// Notification sound identifier (e.g., 'cyber_pulse', 'alert_neon', 'system_custom')
  final String notificationSoundId;

  /// Custom system sound URI (for Android system picker selection)
  final String? customSystemSoundUri;

  /// Selected notification timer options for this task.
  final Set<NotificationTimerOption> notificationTimerOptions;

  RecurringTask copyWithGeneratedThrough(DateTime date) => RecurringTask(
        id: id,
        title: title,
        description: description,
        category: category,
        weekdays: weekdays,
        firstDate: firstDate,
        startTime: startTime,
        endTime: endTime,
        isTimeBound: isTimeBound,
        reminderIntervalMinutes: reminderIntervalMinutes,
        createdAt: createdAt,
        generatedThrough: date,
        customNotificationMessage: customNotificationMessage,
        notificationSoundId: notificationSoundId,
        customSystemSoundUri: customSystemSoundUri,
        notificationTimerOptions: notificationTimerOptions,
      );

  Task occurrenceOn(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    if (day.isBefore(
            DateTime(firstDate.year, firstDate.month, firstDate.day)) ||
        !weekdays.contains(day.weekday)) {
      throw ArgumentError('Date is outside the recurrence');
    }
    DateTime at(DateTime clock) => DateTime(
          day.year,
          day.month,
          day.day,
          clock.hour,
          clock.minute,
          clock.second,
        );
    final start = at(startTime);
    final end = at(endTime);
    final endAdjusted = end.isAfter(start) ? end : end.add(const Duration(days: 1));
    return Task(
      title: title,
      description: description,
      category: category,
      targetDate: day,
      startTime: start,
      endTime: endAdjusted,
      isTimeBound: isTimeBound,
      reminderIntervalMinutes: reminderIntervalMinutes,
      recurringDefinitionId: id,
      customNotificationMessage: customNotificationMessage,
      notificationSoundId: notificationSoundId,
      customSystemSoundUri: customSystemSoundUri,
      notificationTimerOptions: notificationTimerOptions,
    );
  }
}

/// Separate type ID and box keep pre-existing Task records intact.
class RecurringTaskAdapter extends TypeAdapter<RecurringTask> {
  @override
  final int typeId = 1;

  @override
  RecurringTask read(BinaryReader reader) {
    final fields = <int, dynamic>{};
    final count = reader.readByte();
    for (var i = 0; i < count; i++) {
      fields[reader.readByte()] = reader.read();
    }
    // Handle backward compatibility: category was stored as String, now as int (enum index)
    final categoryValue = fields[3];
    TaskCategory category;
    if (categoryValue is int) {
      category = TaskCategory.values[categoryValue.clamp(0, TaskCategory.values.length - 1)];
    } else if (categoryValue is String) {
      category = TaskCategoryX.fromString(categoryValue);
    } else {
      category = TaskCategory.etc;
    }
    // Handle backward compatibility: customNotificationMessage is field 12, notificationSoundId is 13, customSystemSoundUri is 14, notificationTimerOptions is 15
    final customMessage = fields[12] as String?;
    final notificationSoundId = fields[13] as String? ?? 'cyber_pulse';
    final customSystemSoundUri = fields[14] as String?;
    final notificationTimerOptions = fields[15] as List?;
    return RecurringTask(
      id: fields[0] as String,
      title: fields[1] as String,
      description: fields[2] as String? ?? '',
      category: category,
      weekdays: (fields[4] as List).cast<int>(),
      firstDate: fields[5] as DateTime,
      startTime: fields[6] as DateTime,
      endTime: fields[7] as DateTime,
      isTimeBound: fields[8] as bool? ?? true,
      reminderIntervalMinutes: fields[9] as int? ?? 60,
      createdAt: fields[10] as DateTime,
      generatedThrough: fields[11] as DateTime?,
      customNotificationMessage: customMessage,
      notificationSoundId: notificationSoundId,
      customSystemSoundUri: customSystemSoundUri,
      notificationTimerOptions: notificationTimerOptions != null
          ? notificationTimerOptions
              .map((e) => NotificationTimerOption.values[e as int])
              .toSet()
          : const {},
    );
  }

  @override
  void write(BinaryWriter writer, RecurringTask task) {
    writer
      ..writeByte(16) // Updated field count
      ..writeByte(0)
      ..write(task.id)
      ..writeByte(1)
      ..write(task.title)
      ..writeByte(2)
      ..write(task.description)
      ..writeByte(3)
      ..write(task.category.index)
      ..writeByte(4)
      ..write(task.weekdays)
      ..writeByte(5)
      ..write(task.firstDate)
      ..writeByte(6)
      ..write(task.startTime)
      ..writeByte(7)
      ..write(task.endTime)
      ..writeByte(8)
      ..write(task.isTimeBound)
      ..writeByte(9)
      ..write(task.reminderIntervalMinutes)
      ..writeByte(10)
      ..write(task.createdAt)
      ..writeByte(11)
      ..write(task.generatedThrough)
      ..writeByte(12)
      ..write(task.customNotificationMessage)
      ..writeByte(13)
      ..write(task.notificationSoundId)
      ..writeByte(14)
      ..write(task.customSystemSoundUri)
      ..writeByte(15)
      ..write(task.notificationTimerOptions.map((e) => e.index).toList());
  }
}
