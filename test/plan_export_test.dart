import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twince/screens/plan_screen.dart';
import 'package:twince/services/plan_export.dart';
import 'package:twince/services/plan_service.dart';

PlanDefinition samplePlan() => PlanDefinition(
      id: 'plan-1',
      name: 'دانشگاه · University',
      university: true,
      anchorMonday: DateTime.utc(2026, 10, 19),
      anchorOdd: true,
      entries: const [
        PlanEntry(
          id: 'z-class',
          title: 'ریاضی',
          description: 'فصل اول',
          weekday: 1,
          weeks: 'odd',
          startSecond: 9 * 3600,
          endSecond: 10 * 3600 + 30 * 60,
          reminderMinutes: 15,
        ),
        PlanEntry(
          id: 'f-class',
          title: 'Physics',
          description: '',
          weekday: 3,
          weeks: 'even',
          startSecond: 8 * 3600,
          endSecond: 9 * 3600 + 15 * 60,
          reminderMinutes: 15,
        ),
        PlanEntry(
          id: 'both-class',
          title: 'Lab',
          description: 'Shared',
          weekday: 5,
          weeks: 'both',
          startSecond: 13 * 3600,
          endSecond: 15 * 3600,
          reminderMinutes: 15,
        ),
      ],
    );

void main() {
  const exportedAt = '2026-10-25T08:00:00.000Z';

  Map<String, Object?> document() => buildPlanExport(
        samplePlan(),
        exportedAt: DateTime.utc(2026, 10, 25, 8),
        timeZoneOffset: const Duration(hours: 3, minutes: 30),
      );

  test('export is valid json with the plan id, title, and every task', () {
    final json = encodePlanExport(document());
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    expect(decoded['format'], 'twince-plan');
    expect(decoded['version'], 1);
    expect(decoded['exportedAt'], exportedAt);
    expect(decoded['timezone'], '+03:30');
    expect(
        decoded['plan']['weekReference'], {'evenLabel': 'F', 'oddLabel': 'Z'});
    final plan = decoded['plan'] as Map<String, dynamic>;
    expect(plan['id'], 'plan-1');
    expect(plan['title'], 'دانشگاه · University');
    final tasks = plan['tasks'] as List;
    expect(tasks.map((task) => task['id']),
        ['z-class', 'f-class', 'both-class', 'both-class']);
    expect(
        tasks.map((task) => task['title']), ['ریاضی', 'Physics', 'Lab', 'Lab']);
    final again = encodePlanExport(document());
    expect(jsonDecode(again), decoded);
  });

  test('end time is exported and Z/F weeks keep the stored parity', () {
    final plan = document()['plan']! as Map<String, Object?>;
    final tasks = plan['tasks']! as List;
    final z = tasks[0] as Map;
    expect(z['endTime'], '10:30');
    expect(z['days'], ['mon']);
    expect(z['weekType'], 'odd');
    expect(z['weekLabel'], 'Z');
    expect(z['description'], 'فصل اول');
    final f = tasks[1] as Map;
    expect(f['endTime'], '09:15');
    expect(f['days'], ['wed']);
    expect(f['weekType'], 'even');
    expect(f['weekLabel'], 'F');
    final bothZ = tasks[2] as Map;
    final bothF = tasks[3] as Map;
    expect(bothZ['weekType'], 'odd');
    expect(bothZ['weekLabel'], 'Z');
    expect(bothF['weekType'], 'even');
    expect(bothF['weekLabel'], 'F');
    expect(bothZ['days'], ['fri']);
    expect(bothZ['endTime'], '15:00');
  });

  test('a missing end time is rejected and nothing is encoded', () {
    final plan = PlanDefinition(
      id: 'plan-1',
      name: 'University',
      university: true,
      anchorMonday: DateTime.utc(2026, 10, 19),
      anchorOdd: true,
      entries: const [
        PlanEntry(
          id: 'broken',
          title: 'No end',
          description: '',
          weekday: 2,
          weeks: 'odd',
          startSecond: 9 * 3600,
          endSecond: 24 * 3600,
          reminderMinutes: 15,
        ),
      ],
    );
    expect(
      () => buildPlanExport(
        plan,
        exportedAt: DateTime.utc(2026, 10, 25),
        timeZoneOffset: Duration.zero,
      ),
      throwsA(isA<PlanExportException>()),
    );
  });

  testWidgets('export copies the complete raw json', (tester) async {
    String? copied;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PlanExportButton(
          plan: samplePlan(),
          copyText: (text) async => copied = text,
        ),
      ),
    ));
    await tester.tap(find.byTooltip('Export JSON'));
    await tester.pump();
    final decoded = jsonDecode(copied!) as Map<String, dynamic>;
    expect(decoded['plan']['id'], 'plan-1');
    expect(copied!.startsWith('{'), isTrue);
    expect(copied!.contains('```'), isFalse);
    expect(find.text('Plan JSON copied to clipboard'), findsOneWidget);
  });

  testWidgets('the default action copies raw json to the clipboard',
      (tester) async {
    String? stored;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          stored = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: PlanExportButton(plan: samplePlan())),
    ));
    await tester.tap(find.byTooltip('Export JSON'));
    await tester.pump();
    final decoded = jsonDecode(stored!) as Map<String, dynamic>;
    expect(decoded['format'], 'twince-plan');
    expect((decoded['plan'] as Map)['title'], 'دانشگاه · University');
    expect(stored!.contains('```'), isFalse);
    expect(find.text('Plan JSON copied to clipboard'), findsOneWidget);
  });
}
