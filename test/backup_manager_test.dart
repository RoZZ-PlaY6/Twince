import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twince/widgets/export_backup_button.dart';

void main() {
  testWidgets('import icon opens backup actions and the gear is gone',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ExportBackupButton())),
    );

    expect(find.byTooltip('Backup settings'), findsNothing);
    expect(find.byTooltip('Import Backup / بازیابی'), findsOneWidget);

    await tester.tap(find.byTooltip('Import Backup / بازیابی'));
    await tester.pumpAndSettle();

    expect(find.text('Import backup'), findsOneWidget);
    expect(find.text('Save to current backup'), findsOneWidget);
    expect(find.text('Create new backup'), findsOneWidget);
    expect(find.text('Current backup: none'), findsOneWidget);
    expect(find.text('Rename backup file'), findsOneWidget);
    expect(
      find.text(
          'Import a backup or create one before saving to the current file.'),
      findsOneWidget,
    );
    final save = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save to current backup'));
    expect(save.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'current backup enables save and keeps a long name inside the card',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const name = 'semester-plan-backup-with-a-very-long-file-name.json';
    SharedPreferences.setMockInitialValues({
      'twince_active_backup_name': name,
      'twince_active_backup_path': r'C:\backups\semester.json',
    });
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(1.3)),
        child: child!,
      ),
      home: const Scaffold(body: ExportBackupButton()),
    ));

    await tester.tap(find.byTooltip('Import Backup / بازیابی'));
    await tester.pumpAndSettle();

    expect(find.text('Current backup: $name'), findsOneWidget);
    expect(
      find.text(
          'Import a backup or create one before saving to the current file.'),
      findsNothing,
    );
    final save = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save to current backup'));
    expect(save.onPressed, isNotNull);
    final filename = tester.widget<Text>(find.text('Current backup: $name'));
    expect(filename.maxLines, 1);
    expect(filename.overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull);
  });
}
