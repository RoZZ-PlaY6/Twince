import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twince/models/task.dart';
import 'package:twince/screens/alarm_ring_screen.dart';
import 'package:twince/services/alarm_restart.dart';

void _noop() {}

void _ignore(int _) {}

void main() {
  test('restart copies settings onto a new task and leaves the source alone',
      () {
    final source = Task(
      id: 'original',
      title: 'Morning workout',
      description: 'Stretch first',
      category: TaskCategory.important,
      targetDate: DateTime(2026, 10, 23),
      startTime: DateTime(2026, 10, 23, 7),
      endTime: DateTime(2026, 10, 23, 7, 30),
      reminderIntervalMinutes: 15,
      recurringDefinitionId: 'series',
      notificationTimerOptions: {NotificationTimerOption.fiveMinutes},
      isAlarm: true,
      alarmSoundType: AlarmSoundType.builtIn,
      alarmSoundId: 'gentle_bell',
      status: TaskStatus.pending,
    );
    final now = DateTime(2026, 10, 23, 7, 30);
    final copy = buildRestartedAlarmTaskFromMap({
      'title': source.title,
      'description': source.description,
      'category': source.category.name,
      'startAtMillis': now.millisecondsSinceEpoch,
      'endAtMillis':
          now.add(const Duration(minutes: 30)).millisecondsSinceEpoch,
      'soundType': source.alarmSoundType.name,
      'soundId': source.alarmSoundId,
      'reminderIntervalMinutes': source.reminderIntervalMinutes,
      'notificationTimers': 'fiveMinutes',
    }, now);

    expect(copy.id, isNot(source.id));
    expect(copy.recurringDefinitionId, isNull);
    expect(copy.status, TaskStatus.pending);
    expect(source.status, TaskStatus.pending);
    expect(source.recurringDefinitionId, 'series');
    expect(copy.title, 'Morning workout');
    expect(copy.category, TaskCategory.important);
    expect(copy.alarmSoundId, 'gentle_bell');
    expect(copy.isAlarm, isTrue);
    expect(
        copy.endTime.difference(copy.startTime), const Duration(minutes: 30));
    expect(copy.targetDate, DateTime(2026, 10, 23));
    expect(
        copy.notificationTimerOptions, {NotificationTimerOption.fiveMinutes});
    expect(alarmSnoozeDelay(5), const Duration(minutes: 5));
    expect(alarmSnoozeDelay(10), const Duration(minutes: 10));
    expect(alarmSnoozeDelay(15), isNull);
  });

  testWidgets('alarm screen reference layout', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AlarmRingScreen(
        timeLabel: '07:30',
        title: 'Morning workout',
        onDismiss: _noop,
        onRestart: _noop,
        onSnooze: _ignore,
      ),
    ));
    await expectLater(
      find.byType(AlarmRingScreen),
      matchesGoldenFile('goldens/alarm_ring_screen.png'),
    );
  });

  testWidgets('alarm screen fits long titles, large text, and both snoozes',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final snoozes = <int>[];
    var dismissed = 0;
    var restarted = 0;
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: const TextScaler.linear(1.6),
        ),
        child: child!,
      ),
      home: AlarmRingScreen(
        timeLabel: '07:30',
        title:
            'جلسه برنامه‌ریزی پروژه و پیگیری کارهای هفتگی Morning workout review',
        onDismiss: () => dismissed++,
        onRestart: () => restarted++,
        onSnooze: snoozes.add,
      ),
    ));
    expect(find.text('TWINCE'), findsOneWidget);
    expect(find.text('07:30'), findsOneWidget);
    expect(find.text('Dismiss'), findsOneWidget);
    expect(find.text('Restart'), findsOneWidget);
    expect(find.text('Snooze 5min'), findsOneWidget);
    expect(find.text('Snooze 10min'), findsOneWidget);
    expect(tester.takeException(), isNull);

    Future<void> tapLabel(String label) async {
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await tester.pump();
    }

    await tapLabel('Snooze 5min');
    await tapLabel('Snooze 10min');
    await tapLabel('Restart');
    await tapLabel('Dismiss');
    expect(snoozes, [5, 10]);
    expect(restarted, 1);
    expect(dismissed, 1);
    expect(tester.takeException(), isNull);
  });
}
