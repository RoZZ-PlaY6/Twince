import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:twince/models/task.dart';
import 'package:twince/screens/home_screen.dart';
import 'package:twince/services/storage_service.dart';
import 'package:hive/hive.dart';
import 'package:twince/services/weekly_task_service.dart';
import 'package:twince/services/weekly_tasks_clipboard.dart';
import 'package:twince/screens/weekly_tasks_screen.dart';

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
  final List<WeeklyCategory> categories = [];
  @override
  List<WeeklyTask> getAll() => tasks;
  @override
  List<WeeklyCategory> getCategories() => categories;
  @override
  String categoryName(String? categoryId) =>
      categories
          .where((category) => category.id == categoryId)
          .map((category) => category.name)
          .firstOrNull ??
      uncategorizedWeeklyLabel;
  @override
  Future<WeeklyCategory> createCategory(String name) async {
    final category = WeeklyCategory(name: name.trim());
    categories.add(category);
    notifyListeners();
    return category;
  }

  @override
  Future<void> assignCategory(String taskId, String? categoryId) async {
    final index = tasks.indexWhere((task) => task.id == taskId);
    if (index < 0) return;
    tasks[index] = tasks[index].copyWith(categoryId: categoryId);
    notifyListeners();
  }

  @override
  Future<void> deleteCategory(String id) async {
    categories.removeWhere((category) => category.id == id);
    for (var index = 0; index < tasks.length; index++) {
      if (tasks[index].categoryId == id) {
        tasks[index] = tasks[index].copyWith(categoryId: null);
      }
    }
    notifyListeners();
  }

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
  test('older weekly tasks stay uncategorized and new categories persist',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('twince_weekly_cat');
    Hive.init(directory.path);
    final service = await WeeklyTaskService.initialize();
    try {
      final legacy = WeeklyTask.fromJson({
        'id': 'legacy',
        'title': 'Old goal',
        'targetPerWeek': 2,
        'weekKey': weeklyKey(DateTime.now()),
      });
      expect(legacy.categoryId, isNull);
      await service.save(legacy);
      final health = await service.createCategory('Health');
      await service.save(WeeklyTask(
        id: 'run',
        title: 'Run',
        targetPerWeek: 3,
        weekKey: weeklyKey(DateTime.now()),
        categoryId: health.id,
      ));
      final box = Hive.box<String>('weekly_tasks');
      await box.close();
      await Hive.box<String>('weekly_categories').close();
      final reopened = await WeeklyTaskService.initialize();
      expect(
          reopened
              .getAll()
              .singleWhere((task) => task.id == 'legacy')
              .categoryId,
          isNull);
      expect(reopened.categoryName(null), 'Uncategorized');
      final run = reopened.getAll().singleWhere((task) => task.id == 'run');
      expect(reopened.categoryName(run.categoryId), 'Health');
      await reopened.deleteCategory(health.id);
      final kept = reopened.getAll().singleWhere((task) => task.id == 'run');
      expect(kept.title, 'Run');
      expect(kept.categoryId, isNull);
      expect(reopened.getCategories(), isEmpty);
      expect(reopened.getAll().map((task) => task.id), contains('legacy'));
      reopened.dispose();
    } finally {
      service.dispose();
      await Hive.close();
      await directory.delete(recursive: true);
    }
  });
  testWidgets('a task can join or leave a category without being deleted',
      (tester) async {
    final weekly = _WeeklyStore();
    weekly.categories.add(WeeklyCategory(id: 'health', name: 'Health'));
    weekly.tasks.add(WeeklyTask(
      id: 'run',
      title: 'Run',
      targetPerWeek: 3,
      weekKey: weeklyKey(DateTime.now()),
      categoryId: 'health',
    ));
    await tester.pumpWidget(ChangeNotifierProvider<WeeklyTaskService>.value(
      value: weekly,
      child: const MaterialApp(home: Scaffold(body: WeeklyTasksScreen())),
    ));

    await tester.tap(find.byTooltip('Change category'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Remove from category'));
    await tester.pumpAndSettle();

    expect(weekly.tasks.single.title, 'Run');
    expect(weekly.tasks.single.categoryId, isNull);
    expect(find.text('Run'), findsOneWidget);

    await tester.tap(find.byTooltip('Change category'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Health'));
    await tester.pumpAndSettle();
    expect(weekly.tasks.single.categoryId, 'health');

    await tester.tap(find.byTooltip('Delete category Health'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete category'));
    await tester.pumpAndSettle();

    expect(weekly.categories, isEmpty);
    expect(weekly.tasks.single.title, 'Run');
    expect(weekly.tasks.single.categoryId, isNull);
    expect(find.text('Run'), findsOneWidget);
  });
  testWidgets('a task can join or leave a category without being deleted',
      (tester) async {
    final weekly = _WeeklyStore();
    weekly.categories.add(WeeklyCategory(id: 'health', name: 'Health'));
    weekly.tasks.add(WeeklyTask(
      id: 'run',
      title: 'Run',
      targetPerWeek: 3,
      weekKey: weeklyKey(DateTime.now()),
      categoryId: 'health',
    ));
    await tester.pumpWidget(ChangeNotifierProvider<WeeklyTaskService>.value(
      value: weekly,
      child: const MaterialApp(home: Scaffold(body: WeeklyTasksScreen())),
    ));

    await tester.tap(find.byTooltip('Change category'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Remove from category'));
    await tester.pumpAndSettle();

    expect(weekly.tasks.single.title, 'Run');
    expect(weekly.tasks.single.categoryId, isNull);
    expect(find.text('Run'), findsOneWidget);

    await tester.tap(find.byTooltip('Change category'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Health'));
    await tester.pumpAndSettle();
    expect(weekly.tasks.single.categoryId, 'health');

    await tester.tap(find.byTooltip('Delete category Health'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete category'));
    await tester.pumpAndSettle();

    expect(weekly.categories, isEmpty);
    expect(weekly.tasks.single.title, 'Run');
    expect(weekly.tasks.single.categoryId, isNull);
    expect(find.text('Run'), findsOneWidget);
  });
  test('clipboard format has one current-week count per line', () {
    final tasks = [
      WeeklyTask(
          id: 'first',
          title: 'Interview',
          targetPerWeek: 8,
          doneThisWeek: 4,
          weekKey: weeklyKey(DateTime.now())),
      WeeklyTask(
          id: 'second',
          title: 'Study\nplan',
          targetPerWeek: 3,
          doneThisWeek: 1,
          weekKey: weeklyKey(DateTime.now())),
    ];
    expect(formatWeeklyTasks(tasks, heading: 'All'),
        'All\nInterview: 4 / 8\nStudy plan: 1 / 3');
    expect(
      formatWeeklyTasks(tasks, heading: 'hello'),
      'hello\nInterview: 4 / 8\nStudy plan: 1 / 3',
    );
  });

  testWidgets('copying a selected category starts with its name',
      (tester) async {
    final weekly = _WeeklyStore();
    weekly.categories.add(WeeklyCategory(id: 'hello', name: 'hello'));
    weekly.tasks.addAll([
      WeeklyTask(
        id: 'interview',
        title: 'interview',
        targetPerWeek: 6,
        doneThisWeek: 1,
        weekKey: weeklyKey(DateTime.now()),
        categoryId: 'hello',
      ),
      WeeklyTask(
        id: 'spt',
        title: 'spt',
        targetPerWeek: 12,
        doneThisWeek: 10,
        weekKey: weeklyKey(DateTime.now()),
        categoryId: 'hello',
      ),
      WeeklyTask(
        id: 'other',
        title: 'Other',
        targetPerWeek: 2,
        doneThisWeek: 0,
        weekKey: weeklyKey(DateTime.now()),
      ),
    ]);
    String? copiedText;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copiedText =
            (call.arguments as Map<Object?, Object?>)['text'] as String;
      }
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(ChangeNotifierProvider<WeeklyTaskService>.value(
      value: weekly,
      child: const MaterialApp(home: Scaffold(body: WeeklyTasksScreen())),
    ));
    await tester.tap(find.widgetWithText(ChoiceChip, 'hello'));
    await tester.pump();
    await tester.tap(find.text('Copy Tasks'));
    await tester.pump();
    expect(copiedText, 'hello\ninterview: 1 / 6\nspt: 10 / 12');
  });
  testWidgets('copy button copies the current list and shows progress',
      (tester) async {
    final weekly = _WeeklyStore();
    weekly.tasks.add(WeeklyTask(
        id: 'interview',
        title: 'Interview',
        targetPerWeek: 8,
        doneThisWeek: 4,
        weekKey: weeklyKey(DateTime.now())));
    final copying = Completer<void>();
    String? copiedText;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copiedText =
            (call.arguments as Map<Object?, Object?>)['text'] as String;
        await copying.future;
      }
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(ChangeNotifierProvider<WeeklyTaskService>.value(
      value: weekly,
      child: const MaterialApp(home: Scaffold(body: WeeklyTasksScreen())),
    ));
    await tester.tap(find.text('Copy Tasks'));
    await tester.pump();
    expect(copiedText, 'All\nInterview: 4 / 8');
    expect(tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull);
    copying.complete();
    await tester.pumpAndSettle();
    expect(find.text('Copied to clipboard!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final viewport in [
    (const Size(390, 844), 34.0),
    (const Size(360, 640), 24.0),
    (const Size(320, 480), 24.0),
  ]) {
    testWidgets('last weekly card clears add button at ${viewport.$1}',
        (tester) async {
      tester.view.physicalSize = viewport.$1;
      tester.view.devicePixelRatio = 1;
      tester.view.padding = FakeViewPadding(top: 24, bottom: viewport.$2);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);

      final weekly = _WeeklyStore();
      weekly.tasks.addAll([
        for (var index = 0; index < 5; index++)
          WeeklyTask(
            id: 'weekly-$index',
            title: index == 4 ? 'interview' : 'weekly goal $index',
            targetPerWeek: 7,
            weekKey: weeklyKey(DateTime.now()),
          ),
      ]);
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<StorageService>.value(value: _TaskStore([])),
          ChangeNotifierProvider<WeeklyTaskService>.value(value: weekly),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ));
      await tester.tap(find.text('Weekly Tasks'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final scrollable = tester.state<ScrollableState>(find.descendant(
          of: find.byType(ListView).first, matching: find.byType(Scrollable)));
      for (var attempt = 0; attempt < 5; attempt++) {
        scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
        await tester.pump();
        if (scrollable.position.extentAfter < 1) break;
      }
      expect(scrollable.position.extentAfter, lessThan(1));

      final card = find
          .ancestor(
            of: find.text('interview'),
            matching: find.byType(Container),
          )
          .first;
      final button = find.byType(FloatingActionButton);
      expect(tester.getRect(card).bottom,
          lessThanOrEqualTo(tester.getRect(button).top - 8));
      expect(tester.getRect(find.byTooltip('Increase interview')).bottom,
          lessThan(tester.getRect(button).top));
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Add Weekly Task'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Target per week'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('No weekly tasks yet'), findsOneWidget);
    await tester.tap(find.text('Add Weekly Task'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Target per week'), findsOneWidget);
    expect(find.textContaining('alarm sound'), findsNothing);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'), 'Exercise');
    await tester.tap(find.text('Save weekly task'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Exercise'), findsOneWidget);
    await tester.tap(find.byTooltip('Edit weekly task'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Target per week'), '5');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Done this week'), '2');
    await tester.tap(find.text('Save weekly task'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('2 / 5'), findsOneWidget);
    expect(
        weeklyStore.getAll().single.doneThisWeek /
            weeklyStore.getAll().single.targetPerWeek,
        .4);
  });
}
