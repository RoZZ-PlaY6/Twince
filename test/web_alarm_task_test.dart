import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twince/screens/add_task_bottom_sheet.dart';
import 'package:twince/services/alarm_service.dart';
import 'package:twince/services/storage_service.dart';

void main() {
  testWidgets('web creates and edits alarm tasks without Android permission',
      (tester) async {
    if (!kIsWeb) return;
    final storage = await StorageService.initialize(
      null,
      alarms: AlarmService.instance,
    );
    final title = 'Web alarm ${DateTime.now().microsecondsSinceEpoch}';
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) {
          return TextButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => AddTaskBottomSheet(
                storage: storage,
                initialAlarmEnabled: true,
              ),
            ),
            child: const Text('New alarm'),
          );
        }),
      ),
    ));

    await tester.tap(find.text('New alarm'));
    await tester.pump();
    await tester.enterText(find.byType(TextFormField).first, title);
    final create = find.text('Create task');
    await tester.ensureVisible(create);
    await tester.tap(create);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Allow exact alarms in Android settings'),
        findsNothing);
    final created =
        storage.getAllTasks().singleWhere((task) => task.title == title);
    expect(created.isAlarm, isTrue);
    final originalId = created.id;

    // Edit the same persisted occurrence, retaining its ID and alarm settings.
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) {
          return TextButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) =>
                  AddTaskBottomSheet(storage: storage, task: created),
            ),
            child: const Text('Edit alarm'),
          );
        }),
      ),
    ));
    await tester.tap(find.text('Edit alarm'));
    await tester.pump();
    await tester.enterText(find.byType(TextFormField).first, '$title updated');
    final save = find.text('Save changes');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Allow exact alarms in Android settings'),
        findsNothing);
    final edited =
        storage.getAllTasks().singleWhere((task) => task.id == originalId);
    expect(edited.title, '$title updated');
    expect(edited.isAlarm, isTrue);
    expect(edited.alarmSoundType, created.alarmSoundType);
    expect(edited.alarmSoundId, created.alarmSoundId);
    await storage.deleteTask(originalId);
    await tester.pumpWidget(const SizedBox.shrink());
    storage.dispose();
  });
}
