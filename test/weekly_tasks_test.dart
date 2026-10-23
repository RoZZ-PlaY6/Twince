import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:twince/models/task.dart';
import 'package:twince/screens/home_screen.dart';
import 'package:twince/services/storage_service.dart';
import 'package:hive/hive.dart';
import 'package:twince/services/weekly_task_service.dart';

class _TaskStore extends ChangeNotifier implements StorageService {
  _TaskStore(this.tasks);
  final List<Task> tasks;
  @override
  List<Task> getAllTasks() => tasks;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _WeeklyStore extends ChangeNotifier implements WeeklyTaskService {
  final List<WeeklyTask> tasks = [];
  @override
  List<WeeklyTask> getAll() => tasks;
  @override
  Future<void> save(WeeklyTask task) async {
    tasks.removeWhere((existing) => existing.id == task.id);
    tasks.add(task);
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Saturday week keys and bounded weekly progress survive rollover',
      () async {
    final directory = await Directory.systemTemp.createTemp('twince_weekly_');
    Hive.init(directory.path);
    final service = await WeeklyTaskService.initialize();
    final saturday = DateTime(2026, 10, 24);
    final friday = DateTime(2026, 10, 30, 23, 59, 59);
    final followingSaturday = DateTime(2026, 10, 31);
    expect(weeklyKey(saturday), '2026-10-24');
    expect(weeklyKey(friday), '2026-10-24');
    expect(weeklyKey(followingSaturday), '2026-10-31');

    try {
      final task = WeeklyTask(
        id: 'weekly-id',
        title: 'Exercise',
        targetPerWeek: 3,
        weekKey: weeklyKey(DateTime.now()),
      );
      await service.save(task);
      await service.adjust(task.id, 2);
      expect(service.getAll().single.doneThisWeek, 2);
      await service.adjust(task.id, 50);
      expect(service.getAll().single.doneThisWeek, 3);
      final originalKey = weeklyKey(DateTime.now());
      final nextSaturday =
          saturdayOf(DateTime.now()).add(const Duration(days: 7));
      await service.reconcileWeek(now: nextSaturday);
      final reset = service.getAll().single;
      expect(reset.doneThisWeek, 0);
      expect(reset.weekKey, weeklyKey(nextSaturday));
      expect(reset.resultFor(originalKey).done, 3);
      expect(reset.resultFor(originalKey).target, 3);
      expect(reset.id, task.id);
      final box = Hive.box<String>('weekly_tasks');
      await box.close();
      final reopened = await Hive.openBox<String>('weekly_tasks');
      expect(reopened.length, 1);
      final restored = WeeklyTask.fromJson(
          jsonDecode(reopened.get(task.id)!) as Map<String, dynamic>);
      expect(restored.resultFor(originalKey).done, 3);
      expect(restored.weekKey, weeklyKey(nextSaturday));
    } finally {
      service.dispose();
      await Hive.close();
      await directory.delete(recursive: true);
    }
  });
  testWidgets(
      'main Tasks includes alarms and Weekly Tasks opens its focused form',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final day = DateTime.now().add(const Duration(days: 1));
    final taskStore = _TaskStore([
      Task(
        title: 'Alarmed in Tasks',
        isAlarm: true,
        targetDate: day,
        startTime: DateTime(day.year, day.month, day.day, 9),
        endTime: DateTime(day.year, day.month, day.day, 10),
      )
    ]);
    final weeklyStore = _WeeklyStore();
    await tester.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider<StorageService>.value(value: taskStore),
      ChangeNotifierProvider<WeeklyTaskService>.value(value: weeklyStore),
    ], child: const MaterialApp(home: HomeScreen())));
    expect(find.text('Alarmed in Tasks'), findsOneWidget);
    expect(find.text('Alarmed Tasks'), findsNothing);
    await tester.tap(find.text('Weekly Tasks'));
    await tester.pumpAndSettle();
    expect(find.text('No weekly tasks yet'), findsOneWidget);
    await tester.tap(find.text('Add Weekly Task'));
    await tester.pumpAndSettle();
    expect(find.text('Target per week'), findsOneWidget);
    expect(find.textContaining('alarm sound'), findsNothing);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'), 'Exercise');
    await tester.tap(find.text('Save weekly task'));
    await tester.pumpAndSettle();
    expect(find.text('Exercise'), findsOneWidget);
    await tester.tap(find.byTooltip('Edit weekly task'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Target per week'), '5');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Done this week'), '2');
    await tester.tap(find.text('Save weekly task'));
    await tester.pumpAndSettle();
    expect(find.text('2 / 5'), findsOneWidget);
    expect(
        weeklyStore.getAll().single.doneThisWeek /
            weeklyStore.getAll().single.targetPerWeek,
        .4);
  });
}
