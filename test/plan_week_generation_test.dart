import 'dart:io';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twince/models/task.dart';
import 'package:twince/services/plan_service.dart';
import 'package:twince/services/storage_service.dart';
import 'package:twince/services/week_cycle_service.dart';

void main() {
  final clock = DateTime(2026, 10, 27, 8);

  late Directory directory;
  late _RecordingTasks tasks;
  late PlanService plans;
  late WeekCycleService cycle;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp('twince-plan-week');
    Hive.init(directory.path);
    tasks = _RecordingTasks();
    plans = await PlanService.initialize(tasks);
    cycle = WeekCycleService(await SharedPreferences.getInstance());
    await cycle.chooseCurrentWeek(false, now: clock);
    plans.bindWeekCycle(cycle);
    await plans.save(_universityPlan());
    await plans.save(_everyPlan());
    await plans.generateUpcoming(clock: clock);
  });

  tearDown(() async {
    plans.dispose();
    await Hive.close();
    if (directory.existsSync()) {
      await directory.delete(recursive: true);
    }
  });

  test('even Z weeks run Z tasks, odd F weeks run F tasks, and every runs both',
      () async {
    expect(tasks.on(DateTime(2026, 10, 27), 'Z class'), isNotNull);
    expect(tasks.on(DateTime(2026, 11, 3), 'Z class'), isNull);
    expect(tasks.on(DateTime(2026, 10, 28), 'F class'), isNull);
    expect(tasks.on(DateTime(2026, 11, 4), 'F class'), isNotNull);
    expect(tasks.on(DateTime(2026, 10, 29), 'Every class'), isNotNull);
    expect(tasks.on(DateTime(2026, 11, 5), 'Every class'), isNotNull);
    expect(tasks.on(DateTime(2026, 10, 27), 'Both class'), isNotNull);
    expect(tasks.on(DateTime(2026, 11, 3), 'Both class'), isNotNull);

    final zAlarm = tasks.on(DateTime(2026, 10, 27), 'Z class')!;
    final fAlarm = tasks.on(DateTime(2026, 11, 4), 'F class')!;
    expect(zAlarm.isAlarm, isTrue);
    expect(tasks.scheduledAlarms, contains(zAlarm.id));
    expect(tasks.scheduledAlarms, contains(fAlarm.id));

    final before = tasks.tasks.length;
    await plans.generateUpcoming(clock: clock);
    expect(tasks.tasks.length, before);
    expect(
      tasks.tasks.values
          .where((task) =>
              task.title == 'Every class' &&
              _sameDay(task.targetDate, DateTime(2026, 10, 29)))
          .length,
      1,
    );
  });

  test('startup uses the saved Saturday cycle before creating tasks or alarms',
      () async {
    plans.dispose();
    await Hive.box<String>('plan_definitions_v1').clear();
    await Hive.box<String>('plan_occurrences_v1').clear();
    tasks.tasks.clear();
    tasks.scheduledAlarms.clear();
    // An existing plan can carry a different old Monday parity. The saved
    // global Saturday choice is authoritative before any startup generation.
    final oldPlan = PlanDefinition(
      id: 'university',
      name: 'University',
      university: true,
      anchorMonday: DateTime(2026, 10, 19),
      anchorOdd: true,
      entries: _universityPlan().entries,
    );
    await Hive.box<String>('plan_definitions_v1')
        .put(oldPlan.id, jsonEncode(oldPlan.toJson()));
    plans = await PlanService.initialize(tasks, cycle: cycle, clock: clock);
    expect(cycle.isOddOn(clock), isFalse);
    expect(tasks.on(DateTime(2026, 10, 27), 'Z class'), isNotNull);
    expect(tasks.on(DateTime(2026, 10, 28), 'F class'), isNull);
    final z = tasks.on(DateTime(2026, 10, 27), 'Z class')!;
    expect(z.isAlarm, isTrue);
    expect(tasks.scheduledAlarms, contains(z.id));
    final originalIds = tasks.tasks.keys.toSet();
    await plans.generateUpcoming(clock: clock);
    expect(tasks.tasks.keys.toSet(), originalIds);
    final reloadedCycle =
        WeekCycleService(await SharedPreferences.getInstance());
    expect(reloadedCycle.isOddOn(clock), isFalse);
    plans.dispose();
    plans =
        await PlanService.initialize(tasks, cycle: reloadedCycle, clock: clock);
    expect(tasks.tasks.keys.toSet(), originalIds);
    expect(tasks.scheduledAlarms.where((id) => id == z.id).length, 1);
  });
  test('the pencil week change rebuilds active tasks and alarms', () async {
    final removed = tasks.on(DateTime(2026, 10, 27), 'Z class')!;
    expect(tasks.scheduledAlarms, contains(removed.id));

    await cycle.chooseCurrentWeek(true, now: clock);
    await plans.generateUpcoming(clock: clock);

    expect(tasks.on(DateTime(2026, 10, 27), 'Z class'), isNull);
    expect(tasks.scheduledAlarms, isNot(contains(removed.id)));
    expect(tasks.cancelledAlarms, contains(removed.id));
    expect(tasks.on(DateTime(2026, 10, 28), 'F class'), isNotNull);
    expect(tasks.on(DateTime(2026, 11, 3), 'Z class'), isNotNull);
    expect(tasks.on(DateTime(2026, 11, 4), 'F class'), isNull);
    expect(tasks.on(DateTime(2026, 10, 29), 'Every class'), isNotNull);
    expect(tasks.on(DateTime(2026, 11, 5), 'Every class'), isNotNull);
    expect(
      tasks.tasks.values
          .where((task) =>
              task.title == 'Every class' &&
              _sameDay(task.targetDate, DateTime(2026, 10, 29)))
          .length,
      1,
    );
    expect(tasks.scheduledAlarms,
        contains(tasks.on(DateTime(2026, 10, 28), 'F class')!.id));
  });
}

bool _sameDay(DateTime value, DateTime day) =>
    value.year == day.year && value.month == day.month && value.day == day.day;

PlanDefinition _universityPlan() => PlanDefinition(
      id: 'university',
      name: 'University',
      university: true,
      anchorMonday: DateTime(2026, 10, 19),
      anchorOdd: false,
      entries: [
        _entry('z', 'Z class', DateTime.tuesday, 'even'),
        _entry('f', 'F class', DateTime.wednesday, 'odd'),
        _entry('both', 'Both class', DateTime.tuesday, 'both'),
      ],
    );

PlanDefinition _everyPlan() => PlanDefinition(
      id: 'every',
      name: 'ETC',
      university: false,
      anchorMonday: DateTime(2026, 10, 19),
      anchorOdd: true,
      entries: [
        _entry('every', 'Every class', DateTime.thursday, 'both'),
      ],
    );

PlanEntry _entry(String id, String title, int weekday, String weeks) =>
    PlanEntry(
      id: id,
      title: title,
      description: '',
      weekday: weekday,
      weeks: weeks,
      startSecond: 9 * 3600,
      endSecond: 10 * 3600,
      reminderMinutes: 15,
      taskOptions: const {'isAlarm': true},
    );

class _RecordingTasks extends ChangeNotifier implements StorageService {
  final tasks = <String, Task>{};
  final scheduledAlarms = <String>{};
  final cancelledAlarms = <String>[];

  Task? on(DateTime day, String title) {
    for (final task in tasks.values) {
      if (task.title == title && _sameDay(task.targetDate, day)) return task;
    }
    return null;
  }

  @override
  List<Task> getAllTasks() => tasks.values.toList();

  @override
  Future<void> addTask(Task task) async {
    if (tasks.containsKey(task.id)) {
      throw StateError('Task already exists');
    }
    tasks[task.id] = task;
    if (task.isAlarm && task.status == TaskStatus.pending) {
      scheduledAlarms.add(task.id);
    }
  }

  @override
  Future<void> deleteTask(String id) async {
    tasks.remove(id);
    if (scheduledAlarms.remove(id)) cancelledAlarms.add(id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
