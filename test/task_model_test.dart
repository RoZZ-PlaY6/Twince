import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:twince/models/task.dart';
import 'package:twince/models/recurring_task.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    Hive.registerAdapter(TaskAdapter());
    Hive.registerAdapter(RecurringTaskAdapter());
  });

  test('Hive persists all task fields and status changes', () async {
    final directory = await Directory.systemTemp.createTemp('twince_test_');
    Hive.init(directory.path);
    final date = DateTime(2026, 10, 5);
    final start = DateTime(2026, 10, 5, 9);
    final end = DateTime(2026, 10, 5, 11);
    try {
      var box = await Hive.openBox<Task>('tasks_test');
      final task = Task(
        id: 'known-id',
        title: '  Write report  ',
        description: 'Draft',
        category: TaskCategory.important,
        targetDate: date,
        startTime: start,
        endTime: end,
        reminderIntervalMinutes: 30,
        createdAt: start.subtract(const Duration(days: 1)),
        customNotificationMessage: 'Custom reminder message',
        isAlarm: true,
        alarmSoundType: AlarmSoundType.customFile,
        alarmSoundId: 'picked.mp3',
        alarmSoundUri: 'content://audio/picked',
      );
      await box.put(task.id, task.copyWith(status: TaskStatus.failed));
      await box.close();
      box = await Hive.openBox<Task>('tasks_test');
      final restored = box.get('known-id')!;
      expect(restored.title, 'Write report');
      expect(restored.description, 'Draft');
      expect(restored.category, TaskCategory.important);
      expect(restored.status, TaskStatus.failed);
      expect(restored.isTimeBound, isTrue);
      expect(restored.targetDate, date);
      expect(restored.startTime, start);
      expect(restored.endTime, end);
      expect(restored.reminderIntervalMinutes, 30);
      expect(restored.completedAt, isNull);
      expect(restored.customNotificationMessage, 'Custom reminder message');
      expect(restored.isAlarm, isTrue);
      expect(restored.alarmSoundType, AlarmSoundType.customFile);
      expect(restored.alarmSoundId, 'picked.mp3');
      expect(restored.alarmSoundUri, 'content://audio/picked');
      await box.close();
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('Hive persists task without custom notification message', () async {
    final directory = await Directory.systemTemp.createTemp('twince_test2_');
    Hive.init(directory.path);
    final date = DateTime(2026, 10, 5);
    final start = DateTime(2026, 10, 5, 9);
    final end = DateTime(2026, 10, 5, 11);
    try {
      var box = await Hive.openBox<Task>('tasks_test2');
      final task = Task(
        id: 'known-id-2',
        title: 'Task without custom message',
        targetDate: date,
        startTime: start,
        endTime: end,
      );
      await box.put(task.id, task);
      await box.close();
      box = await Hive.openBox<Task>('tasks_test2');
      final restored = box.get('known-id-2')!;
      expect(restored.customNotificationMessage, isNull);
      expect(restored.hasCustomNotificationMessage, isFalse);
      expect(restored.isAlarm, isFalse);
      expect(restored.alarmSoundType, AlarmSoundType.system);
      await box.close();
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('Task copyWith handles custom notification message correctly', () {
    final task = Task(
      title: 'Test task',
      targetDate: DateTime(2026, 10, 5),
      startTime: DateTime(2026, 10, 5, 9),
      endTime: DateTime(2026, 10, 5, 11),
      customNotificationMessage: 'Original message',
    );

    // Test updating message
    var updated = task.copyWith(customNotificationMessage: 'Updated message');
    expect(updated.customNotificationMessage, 'Updated message');

    // Test clearing message
    updated = task.copyWith(
        customNotificationMessage: '', clearCustomNotificationMessage: true);
    expect(updated.customNotificationMessage, isNull);

    // Test whitespace-only clears
    updated = task.copyWith(
        customNotificationMessage: '   ', clearCustomNotificationMessage: true);
    expect(updated.customNotificationMessage, isNull);
  });

  test('recurrence and task instances use separate adapters and states',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('twince_recurring_');
    Hive.init(directory.path);
    try {
      var definitions = await Hive.openBox<RecurringTask>('recurring_test');
      var tasks = await Hive.openBox<Task>('instances_test');
      final monday = DateTime(2026, 10, 5);
      final definition = RecurringTask(
        title: 'Exercise',
        weekdays: [1, 3],
        firstDate: monday,
        startTime: DateTime(2026, 10, 5, 7, 30, 5),
        endTime: DateTime(2026, 10, 5, 8, 30, 5),
        customNotificationMessage: 'Recurring custom message',
        isAlarm: true,
        alarmSoundType: AlarmSoundType.builtIn,
        alarmSoundId: 'gentle_bell',
      );
      final first = definition.occurrenceOn(monday);
      final second = definition.occurrenceOn(DateTime(2026, 10, 7));
      await definitions.put(definition.id, definition);
      await tasks.put(
          first.id,
          first.copyWith(
              status: TaskStatus.completed,
              completedAt: DateTime(2026, 10, 5, 8)));
      await tasks.put(second.id, second);
      await tasks.close();
      await definitions.close();
      definitions = await Hive.openBox<RecurringTask>('recurring_test');
      tasks = await Hive.openBox<Task>('instances_test');
      expect(tasks.get(first.id)!.status, TaskStatus.completed);
      expect(tasks.get(second.id)!.status, TaskStatus.pending);
      expect(tasks.get(second.id)!.startTime.second, 5);
      expect(tasks.get(first.id)!.recurringDefinitionId, definition.id);
      expect(definitions.get(definition.id)!.title, 'Exercise');
      expect(definitions.get(definition.id)!.weekdays, [1, 3]);
      expect(definitions.get(definition.id)!.customNotificationMessage,
          'Recurring custom message');
      expect(tasks.get(first.id)!.customNotificationMessage,
          'Recurring custom message');
      expect(definitions.get(definition.id)!.isAlarm, isTrue);
      expect(tasks.get(second.id)!.isAlarm, isTrue);
      expect(tasks.get(second.id)!.alarmSoundId, 'gentle_bell');
      await tasks.close();
      await definitions.close();
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
