import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twince/services/backup_files.dart';
import 'package:twince/services/backup_library.dart';
import 'package:twince/widgets/backup_dialogs.dart';
import 'package:twince/widgets/export_backup_button.dart';

void main() {
  test('renaming changes the backup file on disk', () async {
    final directory = await Directory.systemTemp.createTemp('twince-rename');
    final original =
        File('${directory.path}${Platform.pathSeparator}twince_backup.json');
    await original.writeAsString('{"schemaVersion":1,"tasks":[]}');
    addTearDown(() async {
      if (directory.existsSync()) await directory.delete(recursive: true);
    });

    final renamed = await renameBackupCopy(original.path, 'Semester.json');

    expect(renamed, endsWith('${Platform.pathSeparator}Semester.json'));
    expect(File(renamed!).readAsStringSync(), '{"schemaVersion":1,"tasks":[]}');
    expect(original.existsSync(), isFalse);
  });

  test('the saved backup record uses the renamed file', () async {
    final directory = await Directory.systemTemp.createTemp('twince-rename-lib');
    final original =
        File('${directory.path}${Platform.pathSeparator}twince_backup.json');
    await original.writeAsString('{"schemaVersion":1,"plans":[]}');
    SharedPreferences.setMockInitialValues({
      'twince_active_backup_name': 'twince_backup.json',
      'twince_active_backup_path': original.path,
    });
    addTearDown(() async {
      if (directory.existsSync()) await directory.delete(recursive: true);
    });

    final renamed = await BackupLibrary.instance.rename('Semester plan');

    expect(renamed.name, 'Semester plan.json');
    expect(File(renamed.path!).readAsStringSync(), '{"schemaVersion":1,"plans":[]}');
    expect(original.existsSync(), isFalse);
    final stored = await BackupLibrary.instance.current();
    expect(stored?.name, 'Semester plan.json');
    expect(stored?.path, renamed.path);
  });

  testWidgets('Rename backup file opens a name input', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showBackupNameDialog(
              context,
              initialName: 'twince_backup.json',
              title: 'Rename backup file',
              action: 'Rename',
            ),
            child: const Text('Rename backup file'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Rename backup file'));
    await tester.pump();

    expect(find.widgetWithText(AlertDialog, 'Rename backup file'), findsOneWidget);
    expect(find.byType(TextField).hitTestable(), findsOneWidget);
    await tester.enterText(find.byType(TextField).hitTestable(), 'Semester plan');
    expect(find.text('Semester plan'), findsOneWidget);
  });

  testWidgets('the backup sheet rename button is present', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ExportBackupButton())),
    );
    await tester.tap(find.byTooltip('Import Backup / بازیابی'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Rename backup file'), findsOneWidget);
  });
}
