import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:twince/models/recurring_task.dart';
import 'package:twince/models/task.dart';
import 'package:twince/screens/analytics_screen.dart';
import 'package:twince/services/storage_service.dart';
import 'package:twince/services/weekly_task_service.dart';

Task analyticsTask(String title, DateTime date, TaskStatus status,
        {String? series,
        String? id,
        TaskCategory category = TaskCategory.etc}) =>
    Task(
      id: id,
      title: title,
      targetDate: date,
      startTime: DateTime(date.year, date.month, date.day, 9),
      endTime: DateTime(date.year, date.month, date.day, 10),
      status: status,
      category: category,
      recurringDefinitionId: series,
    );

class _AnalyticsStorage extends ChangeNotifier implements StorageService {
  _AnalyticsStorage(this.tasks, {this.definitions = const []});
  final List<Task> tasks;
  final List<RecurringTask> definitions;

  @override
  List<Task> getAllTasks() => tasks;

  @override
  List<RecurringTask> getRecurringTasks() => definitions;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _WeeklyStorage extends ChangeNotifier implements WeeklyTaskService {
  _WeeklyStorage(this.tasks);
  final List<WeeklyTask> tasks;
  @override
  List<WeeklyTask> getAll() => tasks;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('chart modes follow filters and hide recurring occurrence rows',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    final nextMonth = DateTime(today.year, today.month + 1, 10);
    Task task(String title, DateTime date, TaskStatus status,
            {String? series}) =>
        Task(
          title: title,
          targetDate: date,
          startTime: DateTime(date.year, date.month, date.day, 9),
          endTime: DateTime(date.year, date.month, date.day, 10),
          status: status,
          recurringDefinitionId: series,
        );
    final storage = _AnalyticsStorage([
      task('Visible standard', day, TaskStatus.completed),
      task('Hidden recurring title', day, TaskStatus.failed,
          series: 'series-1'),
      task('Next month standard', nextMonth, TaskStatus.pending),
    ]);

    final weekly = _WeeklyStorage([
      WeeklyTask(
          title: 'Exercise goal',
          targetPerWeek: 7,
          doneThisWeek: 3,
          weekKey: weeklyKey(day))
    ]);
    await tester.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider<WeeklyTaskService>.value(value: weekly),
      ChangeNotifierProvider<StorageService>.value(value: storage),
    ], child: const MaterialApp(home: AnalyticsScreen())));
    expect(find.text('Visible standard'), findsOneWidget);
    expect(find.text('Hidden recurring title'), findsOneWidget);
    expect(
        find.textContaining('2 occurrences · 50.0% completed'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.donut_large_rounded));
    await tester.pump();
    expect(find.text('50%'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.stacked_bar_chart_rounded));
    await tester.pump();
    expect(find.text('50.0%'), findsWidgets);

    await tester.tap(find.text('Monthly'));
    await tester.pump();
    expect(find.text('Visible standard'), findsOneWidget);
    expect(find.text('Next month standard'), findsNothing);
    await tester.tap(find.byTooltip('Next'));
    await tester.pump();
    expect(find.text('Next month standard'), findsOneWidget);
    expect(find.text('Visible standard'), findsNothing);
    await tester.tap(find.byTooltip('Previous'));
    await tester.pump();
    await tester.tap(find.text('Weekly tasks'));
    await tester.pump();
    expect(find.text('Exercise goal'), findsOneWidget);
    expect(find.text('Next month standard'), findsNothing);
    await tester.tap(find.text('Percentage'));
    await tester.pump();
    expect(find.textContaining('42.9%'), findsWidgets);
    await tester.tap(find.text('Tasks'));
    await tester.pump();
    expect(find.text('Visible standard'), findsOneWidget);
  });

  test('filters count each occurrence once inside the date range', () {
    final monday = DateTime(2026, 10, 19);
    final wednesday = DateTime(2026, 10, 21);
    final nextMonth = DateTime(2026, 11, 2);
    final tasks = [
      analyticsTask('Report', monday, TaskStatus.completed, id: 'standard'),
      analyticsTask('Lecture', monday, TaskStatus.failed,
          id: 'series-mon', series: 'course'),
      analyticsTask('Lecture', wednesday, TaskStatus.pending,
          id: 'series-wed', series: 'course'),
      analyticsTask('Lecture', nextMonth, TaskStatus.completed,
          id: 'series-nov', series: 'course'),
      analyticsTask('Lecture', monday, TaskStatus.failed,
          id: 'series-mon', series: 'course'),
    ];
    final weekStart = DateTime(2026, 10, 19);
    final weekEnd = DateTime(2026, 10, 25);

    final all = filterAnalyticsTasks(tasks,
        rangeStart: weekStart, rangeEnd: weekEnd, type: AnalyticsTaskType.all);
    final standard = filterAnalyticsTasks(tasks,
        rangeStart: weekStart,
        rangeEnd: weekEnd,
        type: AnalyticsTaskType.standard);
    final repeated = filterAnalyticsTasks(tasks,
        rangeStart: weekStart,
        rangeEnd: weekEnd,
        type: AnalyticsTaskType.repeated);

    expect(
        all.map((task) => task.id), ['standard', 'series-mon', 'series-wed']);
    expect(standard.map((task) => task.title), ['Report']);
    expect(repeated.map((task) => task.id), ['series-mon', 'series-wed']);
    expect(analyticsCompletionRate(all), 100 / 3);
    expect(analyticsCompletionRate(standard), 100);
    expect(analyticsCompletionRate(repeated), 0);
    expect(analyticsCompletionRate(const []), 0);

    final november = filterAnalyticsTasks(tasks,
        rangeStart: DateTime(2026, 11),
        rangeEnd: DateTime(2026, 11, 30),
        type: AnalyticsTaskType.repeated);
    expect(november.map((task) => task.id), ['series-nov']);
  });

  test('groups a series once and classifies it by definition id', () {
    final monday = DateTime(2026, 10, 19);
    final tasks = [
      analyticsTask('test 1 2 3 4', monday, TaskStatus.completed, id: 'plain'),
      for (var day = 0; day < 7; day++)
        analyticsTask(
            'test 1 2 3 4',
            DateTime(2026, 10, 19 + day),
            day == 0
                ? TaskStatus.completed
                : day == 1
                    ? TaskStatus.failed
                    : TaskStatus.pending,
            id: 'day-$day',
            series: 'series'),
      analyticsTask('test 1 2 3 4', DateTime(2026, 11, 2), TaskStatus.pending,
          id: 'later', series: 'series'),
    ];
    final week = filterAnalyticsTasks(tasks,
        rangeStart: monday,
        rangeEnd: DateTime(2026, 10, 25),
        type: AnalyticsTaskType.all);
    final allItems = groupAnalyticsList(week, scheduledWeekdays: {
      'series': const [1, 2, 3, 4, 5, 6, 7],
    });
    expect(
        allItems.whereType<AnalyticsStandardItem>().map((item) => item.task.id),
        ['plain']);
    final series = allItems.whereType<AnalyticsSeriesItem>().single;
    expect(series.definitionId, 'series');
    expect(series.occurrences.map((task) => task.id),
        ['day-0', 'day-1', 'day-2', 'day-3', 'day-4', 'day-5', 'day-6']);
    expect(series.completedCount, 1);
    expect(series.completionLabel, '1/7 completed');
    expect(analyticsWeekdayLabel(series.weekdays),
        'Mon · Tue · Wed · Thu · Fri · Sat · Sun');
    expect(analyticsCompletionRate(week), 200 / 8);

    final repeated = groupAnalyticsList(filterAnalyticsTasks(tasks,
        rangeStart: monday,
        rangeEnd: DateTime(2026, 10, 25),
        type: AnalyticsTaskType.repeated));
    expect(repeated, hasLength(1));
    expect(repeated.single, isA<AnalyticsSeriesItem>());
    expect((repeated.single as AnalyticsSeriesItem).occurrences, hasLength(7));

    final standard = groupAnalyticsList(filterAnalyticsTasks(tasks,
        rangeStart: monday,
        rangeEnd: DateTime(2026, 10, 25),
        type: AnalyticsTaskType.standard));
    expect(standard, hasLength(1));
    expect((standard.single as AnalyticsStandardItem).task.id, 'plain');

    final custom = groupAnalyticsList(filterAnalyticsTasks(tasks,
        rangeStart: DateTime(2026, 10, 20),
        rangeEnd: DateTime(2026, 10, 21),
        type: AnalyticsTaskType.repeated));
    final customSeries = custom.single as AnalyticsSeriesItem;
    expect(customSeries.occurrences.map((task) => task.id), ['day-1', 'day-2']);
    expect(customSeries.completionLabel, '0/2 completed');

    final emptyMonth = groupAnalyticsList(filterAnalyticsTasks(tasks,
        rangeStart: DateTime(2026, 12),
        rangeEnd: DateTime(2026, 12, 31),
        type: AnalyticsTaskType.repeated));
    expect(emptyMonth, isEmpty);
  });

  testWidgets('empty analytics shows zero rate without crashing',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<WeeklyTaskService>.value(
            value: _WeeklyStorage(const [])),
        ChangeNotifierProvider<StorageService>.value(
            value: _AnalyticsStorage(const [])),
      ],
      child: const MaterialApp(home: AnalyticsScreen()),
    ));
    expect(find.text('0.0%'), findsWidgets);
    expect(find.text('No tasks in this range'), findsOneWidget);
    expect(find.text('No data in this range'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('task type filter keeps summaries, list, and chart consistent',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final storage = _AnalyticsStorage([
      analyticsTask('Report', day, TaskStatus.completed, id: 'standard'),
      analyticsTask('Lecture', day, TaskStatus.failed,
          id: 'repeated', series: 'course'),
    ]);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<WeeklyTaskService>.value(
            value: _WeeklyStorage(const [])),
        ChangeNotifierProvider<StorageService>.value(value: storage),
      ],
      child: const MaterialApp(home: AnalyticsScreen()),
    ));

    expect(find.text('Report'), findsOneWidget);
    expect(find.text('Lecture'), findsOneWidget);
    expect(find.text('50.0%'), findsWidgets);
    expect(
        find.textContaining('2 occurrences · 50.0% completed'), findsOneWidget);

    await tester.tap(find.text('Standard'));
    await tester.pump();
    expect(find.text('Report'), findsOneWidget);
    expect(find.text('Lecture'), findsNothing);
    expect(find.textContaining('1 occurrences · 100.0% completed'),
        findsOneWidget);

    await tester.tap(find.byIcon(Icons.donut_large_rounded));
    await tester.pump();
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('Lecture'), findsNothing);

    await tester.tap(find.text('Repeated'));
    await tester.pump();
    expect(find.text('Lecture'), findsOneWidget);
    expect(find.text('Report'), findsNothing);
    expect(find.textContaining('0/1 completed'), findsOneWidget);
    expect(
        find.textContaining('1 occurrences · 0.0% completed'), findsOneWidget);
    expect(find.text('0.0%'), findsWidgets);

    await tester.tap(find.text('All'));
    await tester.pump();
    expect(find.text('Report'), findsOneWidget);
    expect(find.text('Lecture'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
  });

  testWidgets('recurring series stays one expandable row in All and Repeated',
      (tester) async {
    tester.view.physicalSize = const Size(390, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    final monday = day.subtract(Duration(days: day.weekday - 1));
    final definition = RecurringTask(
      id: 'series',
      title: 'test 1 2 3 4',
      weekdays: const [1, 2, 3, 4, 5, 6, 7],
      firstDate: monday,
      startTime: DateTime(monday.year, monday.month, monday.day, 9),
      endTime: DateTime(monday.year, monday.month, monday.day, 10),
    );
    final storage = _AnalyticsStorage([
      analyticsTask('Report', day, TaskStatus.completed, id: 'standard'),
      for (var offset = 0; offset < 7; offset++)
        analyticsTask(
            'test 1 2 3 4',
            DateTime(monday.year, monday.month, monday.day + offset),
            offset == 0
                ? TaskStatus.completed
                : offset == 1
                    ? TaskStatus.failed
                    : TaskStatus.pending,
            id: 'day-$offset',
            series: 'series',
            category: offset == 1
                ? TaskCategory.important
                : offset == 2
                    ? TaskCategory.daily
                    : TaskCategory.etc),
      analyticsTask(
          'test 1 2 3 4',
          DateTime(monday.year, monday.month, monday.day + 40),
          TaskStatus.pending,
          id: 'outside-week',
          series: 'series'),
    ], definitions: [
      definition
    ]);

    Future<void> pumpScreen() async {
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<WeeklyTaskService>.value(
              value: _WeeklyStorage(const [])),
          ChangeNotifierProvider<StorageService>.value(value: storage),
        ],
        child: const MaterialApp(home: AnalyticsScreen()),
      ));
    }

    await pumpScreen();
    expect(find.text('test 1 2 3 4'), findsOneWidget);
    expect(find.text('Report'), findsOneWidget);
    expect(
        find.text('Mon · Tue · Wed · Thu · Fri · Sat · Sun  ·  1/7 completed'),
        findsOneWidget);
    expect(find.text('failed'), findsNothing);
    expect(find.text('ETC'), findsNothing);
    expect(
        find.textContaining('8 occurrences · 25.0% completed'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.expand_more));
    await tester.pump();
    expect(find.text('completed'), findsWidgets);
    expect(find.text('failed'), findsOneWidget);
    expect(find.text('pending'), findsWidgets);
    expect(find.text('ETC'), findsNWidgets(5));
    expect(find.text('Important'), findsOneWidget);
    expect(find.text('Daily'), findsOneWidget);
    expect(find.text('09:00 – 10:00'), findsNWidgets(7));
    expect(
        find.text(DateFormat.yMMMd()
            .format(DateTime(monday.year, monday.month, monday.day + 40))),
        findsNothing);

    await tester.tap(find.text('Repeated'));
    await tester.pump();
    expect(find.text('test 1 2 3 4'), findsNWidgets(8));
    expect(find.text('ETC'), findsNWidgets(5));
    expect(find.text('Report'), findsNothing);
    expect(find.text('failed'), findsOneWidget);
    expect(
        find.textContaining('7 occurrences · 14.3% completed'), findsOneWidget);
    expect(find.text('1'), findsWidgets);

    await tester.tap(find.text('Standard'));
    await tester.pump();
    expect(find.text('test 1 2 3 4'), findsNothing);
    expect(find.text('Report'), findsOneWidget);
    expect(find.text('failed'), findsNothing);
    expect(find.textContaining('1 occurrences · 100.0% completed'),
        findsOneWidget);

    await tester.tap(find.text('All'));
    await tester.pump();
    expect(find.text('test 1 2 3 4'), findsNWidgets(8));
    expect(find.text('ETC'), findsNWidgets(5));
    expect(find.text('Report'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await pumpScreen();
    expect(find.text('All'), findsWidgets);
    expect(find.text('test 1 2 3 4'), findsOneWidget);
    expect(find.text('failed'), findsNothing);
    expect(find.text('0/1 completed'), findsNothing);
  });
}
