import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:twince/models/recurring_task.dart';
import 'package:twince/models/task.dart';
import 'package:twince/services/export_service.dart';
import 'package:twince/services/import_service.dart';
import 'package:twince/services/plan_service.dart';
import 'package:twince/services/storage_service.dart';
import 'package:twince/services/weekly_task_service.dart';

void main() {
  late Directory directory;
  late _MemoryTasks storage;
  late WeeklyTaskService weekly;
  late PlanService plans;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    directory = await Directory.systemTemp.createTemp('twince-backup');
    Hive.init(directory.path);
    storage = _MemoryTasks();
    weekly = await WeeklyTaskService.initialize();
    plans = await PlanService.initialize(storage);
  });

  tearDown(() async {
    plans.dispose();
    weekly.dispose();
    await Hive.close();
    if (directory.existsSync()) await directory.delete(recursive: true);
  });

  test('backup and restore keep tasks, weekly tasks, and plans', () async {
    storage.tasks['read'] = _task('read', 'Read');
    await weekly.save(WeeklyTask(
      id: 'exercise',
      title: 'Exercise',
      targetPerWeek: 3,
      doneThisWeek: 1,
      weekKey: weeklyKey(DateTime.now()),
    ));
    await plans.replaceAll([_plan('university', 'University')]);

    final encoded = ExportService.instance.encodeBackup(
      storage,
      weeklyTasks: weekly,
      plans: plans,
    );
    final payload = jsonDecode(encoded!) as Map<String, dynamic>;
    expect(payload['schemaVersion'], 1);
    expect(payload['weeklyTasks'], isNotEmpty);
    expect(payload['plans'], isNotEmpty);
    expect(
      (payload['hiveRecords'] as List).map((record) => record['box']),
      containsAll(['tasks', 'weekly_tasks', 'plan_definitions_v1']),
    );

    storage.tasks
      ..clear()
      ..['other'] = _task('other', 'Other');
    await weekly.replaceAll([
      WeeklyTask(
        id: 'walk',
        title: 'Walk',
        targetPerWeek: 2,
        weekKey: weeklyKey(DateTime.now()),
      ),
    ]);
    await plans.replaceAll([_plan('etc', 'ETC')]);

    final restored = await ImportService.instance.importFromJson(
      storage,
      encoded,
      weeklyTasks: weekly,
      plans: plans,
    );
    expect(restored.status, ImportStatus.success);
    expect(storage.tasks.values.map((task) => task.title), contains('Read'));
    expect(storage.tasks.containsKey('other'), isFalse);
    expect(weekly.getAll().map((task) => task.title), ['Exercise']);
    expect(plans.plans.map((plan) => plan.name), ['University']);
  });

  test('a tasks-only backup restores tasks and leaves the other sections',
      () async {
    storage.tasks['kept-task'] = _task('kept-task', 'Kept task');
    await weekly.save(WeeklyTask(
      id: 'kept-weekly',
      title: 'Kept weekly',
      targetPerWeek: 4,
      weekKey: weeklyKey(DateTime.now()),
    ));
    await plans.replaceAll([_plan('kept-plan', 'Kept plan')]);
    final tasksOnly = ExportService.instance.encodeBackup(storage)!;

    storage.tasks
      ..clear()
      ..['temporary'] = _task('temporary', 'Temporary');

    final restored = await ImportService.instance.importFromJson(
      storage,
      tasksOnly,
      weeklyTasks: weekly,
      plans: plans,
    );
    expect(restored.status, ImportStatus.success);
    expect(storage.tasks.values.map((task) => task.title), contains('Kept task'));
    expect(
        storage.tasks.values.map((task) => task.title), isNot(contains('Temporary')));
    expect(weekly.getAll().single.title, 'Kept weekly');
    expect(plans.plans.single.name, 'Kept plan');
  });
}

Task _task(String id, String title) {
  final day = DateTime(2026, 10, 27);
  return Task(
    id: id,
    title: title,
    targetDate: day,
    startTime: DateTime(day.year, day.month, day.day, 9),
    endTime: DateTime(day.year, day.month, day.day, 10),
  );
}

PlanDefinition _plan(String id, String name) => PlanDefinition(
      id: id,
      name: name,
      university: false,
      anchorMonday: DateTime(2026, 10, 19),
      anchorOdd: true,
      entries: const [
        PlanEntry(
          id: 'entry',
          title: 'Class',
          description: '',
          weekday: DateTime.tuesday,
          weeks: 'both',
          startSecond: 9 * 3600,
          endSecond: 10 * 3600,
          reminderMinutes: 15,
        ),
      ],
    );

class _MemoryTasks extends ChangeNotifier implements StorageService {
  final tasks = <String, Task>{};

  @override
  List<Task> getAllTasks() => tasks.values.toList();

  @override
  List<RecurringTask> getRecurringTasks() => const [];

  @override
  Future<void> clearAllData() async => tasks.clear();

  @override
  Future<void> addTask(Task task) async => tasks[task.id] = task;

  @override
  Future<void> deleteTask(String id) async => tasks.remove(id);

  @override
  Future<void> generateRecurringInstances({DateTime? now}) async {}

  @override
  Future<void> reconcile() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
