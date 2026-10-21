import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twince/widgets/precise_time_picker.dart';

void main() {
  for (final sample in [
    (
      label: 'Start time',
      hour: 4,
      minute: 30,
      second: 20,
      shownHour: '04',
      period: 'AM'
    ),
    (
      label: 'End time',
      hour: 16,
      minute: 30,
      second: 42,
      shownHour: '04',
      period: 'PM'
    ),
    (
      label: 'Start time',
      hour: 0,
      minute: 5,
      second: 0,
      shownHour: '12',
      period: 'AM'
    ),
    (
      label: 'End time',
      hour: 12,
      minute: 5,
      second: 0,
      shownHour: '12',
      period: 'PM'
    ),
    (
      label: 'End time',
      hour: 23,
      minute: 59,
      second: 31,
      shownHour: '11',
      period: 'PM'
    ),
  ]) {
    testWidgets(
        '${sample.label} displays ${sample.hour}:${sample.minute} without seconds',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      DateTime? result;
      final initial =
          DateTime(2026, 10, 28, sample.hour, sample.minute, sample.second);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                      onPressed: () async => result =
                          await showPreciseTimePicker(
                              context: context,
                              initialTime: initial,
                              label: sample.label),
                      child: const Text('Pick'),
                    ))),
      ));
      await tester.tap(find.text('Pick'));
      await tester.pumpAndSettle();
      final hour = find.byKey(const ValueKey('select-Hour'));
      final minute = find.byKey(const ValueKey('select-Minute'));
      expect(tester.getSize(hour).width, greaterThanOrEqualTo(100));
      expect(find.descendant(of: hour, matching: find.text(sample.shownHour)),
          findsWidgets);
      expect(
          find.descendant(
              of: minute,
              matching: find.text(sample.minute.toString().padLeft(2, '0'))),
          findsWidgets);
      expect(find.text('Second'), findsNothing);
      final toggle = tester
          .widget<SegmentedButton<bool>>(find.byType(SegmentedButton<bool>));
      expect(toggle.selected, {sample.period == 'PM'});
      await tester.tap(find.text('Set time'));
      await tester.pumpAndSettle();
      expect(result, initial); // Hidden stored seconds stay intact on edit.
    });
  }

  testWidgets('switching AM to PM retains minutes and stored seconds',
      (tester) async {
    DateTime? result;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
      body: Builder(
          builder: (context) => TextButton(
                onPressed: () async => result = await showPreciseTimePicker(
                  context: context,
                  initialTime: DateTime(2026, 10, 28, 4, 30, 20),
                  label: 'End time',
                ),
                child: const Text('Pick'),
              )),
    )));
    await tester.tap(find.text('Pick'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PM'));
    await tester.pump();
    await tester.tap(find.text('Set time'));
    await tester.pumpAndSettle();
    expect(result, DateTime(2026, 10, 28, 16, 30, 20));
  });

  testWidgets('changing the hour keeps the minute and converts noon correctly',
      (tester) async {
    DateTime? result;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
      body: Builder(
          builder: (context) => TextButton(
                onPressed: () async => result = await showPreciseTimePicker(
                  context: context,
                  initialTime: DateTime(2026, 10, 28, 11, 30, 20),
                  label: 'Start time',
                ),
                child: const Text('Pick'),
              )),
    )));
    await tester.tap(find.text('Pick'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('select-Hour')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('12').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('PM'));
    await tester.pump();
    await tester.tap(find.text('Set time'));
    await tester.pumpAndSettle();
    expect(result, DateTime(2026, 10, 28, 12, 30, 20));
  });
}
