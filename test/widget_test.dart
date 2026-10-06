import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twince/models/task.dart';
import 'package:twince/widgets/task_card.dart';
import 'package:twince/widgets/precise_time_picker.dart';
import 'package:twince/widgets/test_notification_dialog.dart';
import 'package:twince/widgets/alarm_sound_picker.dart';
import 'package:twince/screens/home_screen.dart';
import 'package:twince/screens/add_task_bottom_sheet.dart';
import 'package:twince/services/alarm_service.dart';

void main() {
  test('start time one minute ahead stays on today', () {
    final now = DateTime(2026, 10, 7, 1, 42);
    final result = resolveTaskSchedule(
      selectedDate: now,
      selectedStartTime: DateTime(2000, 1, 1, 1, 43),
      selectedEndTime: DateTime(2000, 1, 1, 2, 42),
      now: now,
      adjustPassedAlarm: true,
    );

    expect(result.targetDate, DateTime(2026, 10, 7));
    expect(result.startTime, DateTime(2026, 10, 7, 1, 43));
  });

  test('alarm schedule uses the task date and local timezone', () {
    final now = DateTime(2026, 10, 7, 10);
    final result = resolveTaskSchedule(
      selectedDate: DateTime(2026, 10, 9),
      selectedStartTime: DateTime(2000, 1, 1, 8, 30),
      selectedEndTime: DateTime(2000, 1, 1, 9, 45),
      now: now,
      adjustPassedAlarm: true,
    );

    expect(result.targetDate, DateTime(2026, 10, 9));
    expect(result.startTime, DateTime(2026, 10, 9, 8, 30));
    expect(result.endTime, DateTime(2026, 10, 9, 9, 45));
    expect(result.startTime.isUtc, isFalse);
  });

  test('passed alarm time today rolls to tomorrow', () {
    final now = DateTime(2026, 10, 7, 12, 30);
    final result = resolveTaskSchedule(
      selectedDate: now,
      selectedStartTime: DateTime(2000, 1, 1, 9),
      selectedEndTime: DateTime(2000, 1, 1, 10),
      now: now,
      adjustPassedAlarm: true,
    );

    expect(result.targetDate, DateTime(2026, 10, 8));
    expect(result.startTime, DateTime(2026, 10, 8, 9));
  });

  test('active timed-task window remains on today', () {
    final now = DateTime(2026, 10, 7, 12, 30, 40);
    final result = resolveTaskSchedule(
      selectedDate: now,
      selectedStartTime: DateTime(2000, 1, 1, 12, 30, 15),
      selectedEndTime: DateTime(2000, 1, 1, 13),
      now: now,
      adjustPassedAlarm: true,
    );

    expect(result.targetDate, DateTime(2026, 10, 7));
    expect(result.startTime, DateTime(2026, 10, 7, 12, 30, 15));
    expect(result.endTime, DateTime(2026, 10, 7, 13));
  });

  test('Android exact alarm uses the task end time', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    const channel = MethodChannel('twince/alarms');
    MethodCall? captured;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      captured = call;
      return true;
    });
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final now = DateTime.now();
    final task = Task(
      title: 'Timed task',
      targetDate: DateTime(now.year, now.month, now.day),
      startTime: now.add(const Duration(minutes: 1)),
      endTime: now.add(const Duration(hours: 1)),
      isAlarm: true,
    );
    await AlarmService.instance.schedule(task);

    expect(captured?.method, 'schedule');
    expect(
      (captured?.arguments as Map<Object?, Object?>)['triggerAtMillis'],
      task.endTime.millisecondsSinceEpoch,
    );
  });

  test('alarmed task filter keeps only pending future alarms', () {
    final now = DateTime(2026, 10, 6, 12);
    Task task(String title,
            {bool alarm = true,
            TaskStatus status = TaskStatus.pending,
            bool future = true}) =>
        Task(
          title: title,
          status: status,
          targetDate: DateTime(2026, 10, 6),
          startTime: future
              ? now.add(const Duration(hours: 1))
              : now.subtract(const Duration(hours: 1)),
          endTime: future
              ? now.add(const Duration(hours: 2))
              : now.add(const Duration(minutes: 1)),
          isAlarm: alarm,
        );

    final filtered = activeAlarmedTasks([
      task('future alarm'),
      task('normal task', alarm: false),
      task('past alarm', future: false),
      task('completed alarm', status: TaskStatus.completed),
    ], now: now);

    expect(filtered.map((task) => task.title), ['future alarm']);
  });

  testWidgets('alarm sound picker exposes all three sound sources',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AlarmSoundPicker(
          type: AlarmSoundType.builtIn,
          soundId: 'cyber_pulse',
          soundUri: null,
          onChanged: (_, __, ___) {},
        ),
      ),
    ));

    expect(find.text('System'), findsOneWidget);
    expect(find.text('App'), findsOneWidget);
    expect(find.text('File'), findsOneWidget);
    expect(find.text('Cyber Pulse'), findsOneWidget);
  });

  testWidgets('failed tasks show a failed badge and struck-through title', (
    tester,
  ) async {
    var retried = false;
    final day = DateTime(2026, 10, 1);
    final task = Task(
      title: 'Missed window',
      status: TaskStatus.failed,
      targetDate: day,
      startTime: DateTime(2026, 10, 1, 9),
      endTime: DateTime(2026, 10, 1, 10),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskCard(
            task: task,
            onToggle: () {},
            onDelete: () {},
            onEdit: () => retried = true,
            onExpire: () async {},
          ),
        ),
      ),
    );

    expect(find.text('FAILED'), findsOneWidget);
    final title = tester.widget<Text>(find.text('Missed window'));
    expect(title.style?.decoration, TextDecoration.lineThrough);
    await tester.tap(find.byTooltip('Retry / Reschedule'));
    expect(retried, isTrue);
  });

  testWidgets('active window shows progress, countdown, and edit action', (
    tester,
  ) async {
    final now = DateTime.now();
    var edited = false;
    final task = Task(
      title: 'Current task',
      targetDate: DateTime(now.year, now.month, now.day),
      startTime: DateTime(now.year, now.month, now.day),
      endTime: DateTime(now.year, now.month, now.day, 23, 59, 59, 999),
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TaskCard(
          task: task,
          onToggle: () {},
          onDelete: () {},
          onEdit: () => edited = true,
          onExpire: () async {},
        ),
      ),
    ));

    expect(find.byKey(const ValueKey('task-progress-fill')), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    final fill = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('task-progress-fill')),
    );
    expect(fill.constraints!.maxWidth, greaterThan(0));
    expect(fill.decoration, isNotNull);
    expect(find.textContaining('remaining'), findsOneWidget);
    await tester.tap(find.byTooltip('Edit task'));
    expect(edited, isTrue);
  });

  testWidgets('structured time picker preserves initial time and AM/PM toggle',
      (tester) async {
    DateTime? selected;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: Builder(
              builder: (context) => TextButton(
                    onPressed: () async =>
                        selected = await showPreciseTimePicker(
                      context: context,
                      initialTime: DateTime(2026, 10, 1, 8, 9, 10),
                      label: 'Start time',
                    ),
                    child: const Text('Pick time'),
                  ))),
    ));
    await tester.tap(find.text('Pick time'));
    await tester.pumpAndSettle();

    // Toggle AM/PM to PM (should change 8 AM to 8 PM = 20:00)
    await tester.tap(find.text('PM'));
    await tester.pump();

    await tester.tap(find.text('Set time'));
    await tester.pumpAndSettle();
    // 8:09:10 AM -> 8:09:10 PM = 20:09:10
    expect(selected, DateTime(2026, 10, 1, 20, 9, 10));
  });

  testWidgets('time picker 12 AM becomes midnight', (tester) async {
    DateTime? selected;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
      builder: (context) => TextButton(
        onPressed: () async => selected = await showPreciseTimePicker(
          context: context,
          initialTime: DateTime(2026, 10, 1, 12, 2, 3),
          label: 'End time',
        ),
        child: const Text('Pick time'),
      ),
    ))));
    await tester.tap(find.text('Pick time'));
    await tester.pumpAndSettle();

    // Initial time is 12:02:03 (PM by default since hour >= 12)
    // Select AM (12 AM = midnight = 00:00:00)
    await tester.tap(find.text('AM'));
    await tester.pump();

    await tester.tap(find.text('Set time'));
    await tester.pumpAndSettle();
    // 12:02:03 PM -> 12:02:03 AM = 00:02:03
    expect(selected, DateTime(2026, 10, 1, 0, 2, 3));
  });

  testWidgets('expired pending card requests failure', (tester) async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    var expired = false;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: TaskCard(
      task: Task(
        title: 'Expired',
        targetDate: DateTime(yesterday.year, yesterday.month, yesterday.day),
        startTime: DateTime(yesterday.year, yesterday.month, yesterday.day, 8),
        endTime: DateTime(yesterday.year, yesterday.month, yesterday.day, 9),
      ),
      onToggle: () {},
      onDelete: () {},
      onEdit: () {},
      onExpire: () async => expired = true,
    ))));
    await tester.pump();
    expect(expired, isTrue);
  });

  testWidgets('test notification dialog sends custom title and message', (
    tester,
  ) async {
    String? sentTitle;
    String? sentBody;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
            builder: (context) => TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) =>
                        TestNotificationDialog(onSend: (title, body) async {
                      sentTitle = title;
                      sentBody = body;
                      return true;
                    }),
                  ),
                  child: const Text('Open notification dialog'),
                )),
      ),
    ));
    await tester.tap(find.text('Open notification dialog'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Title'), 'Custom alert');
    await tester.enterText(
        find.widgetWithText(TextField, 'Message'), 'Custom body');
    await tester.tap(find.text('Send test'));
    await tester.pumpAndSettle();

    expect(sentTitle, 'Custom alert');
    expect(sentBody, 'Custom body');
    expect(find.text('Test notification sent.'), findsOneWidget);
  });
}
