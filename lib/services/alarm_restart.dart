import '../models/task.dart';

/// Snooze choices shared by the ringing screen and its notification.
const alarmSnoozeMinutes = <int>[5, 10];

Duration? alarmSnoozeDelay(int minutes) =>
    alarmSnoozeMinutes.contains(minutes) ? Duration(minutes: minutes) : null;

/// A new pending task for Restart. The source task is not modified.
Task buildRestartedAlarmTask({
  required String title,
  required String description,
  required String categoryName,
  required int startAtMillis,
  required int endAtMillis,
  required DateTime now,
  required String soundType,
  required String soundId,
  String? soundUri,
  int reminderIntervalMinutes = 60,
  bool isTimeBound = true,
  String notificationSoundId = 'cyber_pulse',
  String? customNotificationMessage,
  String? customSystemSoundUri,
  String notificationTimers = '',
}) {
  final storedStart = DateTime.fromMillisecondsSinceEpoch(startAtMillis);
  final storedEnd = DateTime.fromMillisecondsSinceEpoch(endAtMillis);
  final storedDuration = storedEnd.difference(storedStart);
  final duration = storedDuration > Duration.zero
      ? storedDuration
      : const Duration(hours: 1);
  var start = storedStart;
  var end = storedEnd;
  if (startAtMillis <= 0 || endAtMillis <= startAtMillis || !end.isAfter(now)) {
    start = DateTime(
        now.year, now.month, now.day, now.hour, now.minute, now.second);
    end = start.add(duration);
  }
  final timers = notificationTimers
      .split(',')
      .where((name) => name.isNotEmpty)
      .map(
        (name) => NotificationTimerOption.values
            .where((option) => option.name == name)
            .firstOrNull,
      )
      .whereType<NotificationTimerOption>()
      .toSet();
  return Task(
    title: title.trim().isEmpty ? 'Task alarm' : title,
    description: description,
    category: TaskCategoryX.fromString(categoryName),
    targetDate: DateTime(start.year, start.month, start.day),
    startTime: start,
    endTime: end,
    isTimeBound: isTimeBound,
    reminderIntervalMinutes:
        reminderIntervalMinutes < 1 ? 60 : reminderIntervalMinutes,
    customNotificationMessage: customNotificationMessage,
    notificationSoundId: notificationSoundId,
    customSystemSoundUri: customSystemSoundUri,
    notificationTimerOptions: timers,
    isAlarm: true,
    alarmSoundType: AlarmSoundType.values
            .where((type) => type.name == soundType)
            .firstOrNull ??
        AlarmSoundType.system,
    alarmSoundId: soundId,
    alarmSoundUri: soundUri,
  );
}

Task buildRestartedAlarmTaskFromMap(
        Map<dynamic, dynamic> payload, DateTime now) =>
    buildRestartedAlarmTask(
      title: payload['title'] as String? ?? 'Task alarm',
      description: payload['description'] as String? ?? '',
      categoryName: payload['category'] as String? ?? 'etc',
      startAtMillis: (payload['startAtMillis'] as num?)?.toInt() ?? 0,
      endAtMillis: (payload['endAtMillis'] as num?)?.toInt() ?? 0,
      now: now,
      soundType: payload['soundType'] as String? ?? 'system',
      soundId: payload['soundId'] as String? ?? 'cyber_pulse',
      soundUri: payload['soundUri'] as String?,
      reminderIntervalMinutes:
          (payload['reminderIntervalMinutes'] as num?)?.toInt() ?? 60,
      isTimeBound: payload['isTimeBound'] as bool? ?? true,
      notificationSoundId:
          payload['notificationSoundId'] as String? ?? 'cyber_pulse',
      customNotificationMessage:
          payload['customNotificationMessage'] as String?,
      customSystemSoundUri: payload['customSystemSoundUri'] as String?,
      notificationTimers: payload['notificationTimers'] as String? ?? '',
    );
