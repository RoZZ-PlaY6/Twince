import 'package:flutter_test/flutter_test.dart';
import 'package:twince/services/plan_service.dart';
import 'package:twince/models/task.dart';

void main() {
  test(
      'legacy Monday plan anchors migrate to a Saturday week without losing parity',
      () {
    final plan = PlanDefinition(
      id: 'test-plan',
      name: 'University',
      university: true,
      anchorMonday: DateTime(2026, 10, 19),
      anchorOdd: true,
      entries: const [
        PlanEntry(
          id: 'lecture',
          title: 'Lecture',
          description: '',
          weekday: DateTime.tuesday,
          weeks: 'odd',
          startSecond: 9 * 3600,
          endSecond: 10 * 3600,
          reminderMinutes: 60,
        ),
      ],
    );
    expect(plan.isOddOn(DateTime(2026, 10, 17)), isTrue);
    expect(plan.isOddOn(DateTime(2026, 10, 23, 23, 59)), isTrue);
    expect(plan.isOddOn(DateTime(2026, 10, 24)), isFalse);
    expect(plan.isOddOn(DateTime(2026, 10, 25)), isFalse);
    expect(plan.isOddOn(DateTime(2026, 10, 30)), isFalse);
    expect(plan.isOddOn(DateTime(2026, 10, 31)), isTrue);
    final legacyJson = Map<String, dynamic>.from(plan.toJson())
      ..remove('anchorSaturday');
    final restored = PlanDefinition.fromJson(legacyJson);
    expect(restored.entries.single.title, 'Lecture');
    expect(restored.isOddOn(DateTime(2026, 10, 25)), isFalse);

    final edited = restored.withCurrentWeek(false, DateTime(2026, 10, 25));
    expect(edited.anchorSaturday, DateTime(2026, 10, 24));
    expect(edited.isOddOn(DateTime(2026, 10, 24)), isFalse);
    expect(edited.isOddOn(DateTime(2026, 10, 30)), isFalse);
    expect(edited.isOddOn(DateTime(2026, 10, 31)), isTrue);
    final reloaded = PlanDefinition.fromJson(edited.toJson());
    expect(reloaded.anchorSaturday, DateTime(2026, 10, 24));
    expect(reloaded.isOddOn(DateTime(2026, 10, 31)), isTrue);
  });
  test('plan template retains alarm and notification options in JSON', () {
    final day = DateTime(2026, 10, 27);
    final task = Task(
      id: 'template',
      title: 'Lab',
      description: 'Physics',
      category: TaskCategory.important,
      targetDate: day,
      startTime: DateTime(2026, 10, 27, 9, 30, 15),
      endTime: DateTime(2026, 10, 27, 11),
      reminderIntervalMinutes: 30,
      customNotificationMessage: 'Bring notes',
      notificationSoundId: 'alert_neon',
      notificationTimerOptions: {NotificationTimerOption.fifteenMinutes},
      isAlarm: true,
      alarmSoundType: AlarmSoundType.system,
      alarmSoundId: 'cyber_pulse',
    );
    final entry =
        PlanEntry.fromTask(task, id: 'entry', weekday: 2, weeks: 'odd');
    final restored = PlanEntry.fromJson(entry.toJson());
    final occurrence = restored.taskOn(day, id: 'same-occurrence-id');
    expect(occurrence.id, 'same-occurrence-id');
    expect(occurrence.category, TaskCategory.important);
    expect(occurrence.startTime.second, 15);
    expect(occurrence.isAlarm, isTrue);
    expect(occurrence.alarmSoundId, task.alarmSoundId);
    expect(occurrence.notificationSoundId, task.notificationSoundId);
    expect(occurrence.customNotificationMessage, 'Bring notes');
    expect(occurrence.notificationTimerOptions,
        contains(NotificationTimerOption.fifteenMinutes));
    final legacy = Map<String, dynamic>.from(entry.toJson())
      ..remove('taskOptions');
    expect(
        PlanEntry.fromJson(legacy).taskOn(day, id: 'legacy').isAlarm, isFalse);
  });
}
