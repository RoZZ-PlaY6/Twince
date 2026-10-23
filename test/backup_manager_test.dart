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
    expect(find.text('Rename'), findsOneWidget);
    expect(
      find.text(
          'Import a backup or create one before saving to the current file.'),
      findsOneWidget,
    );
  });
}
