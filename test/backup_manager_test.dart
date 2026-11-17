import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twince/services/backup_library.dart';
import 'package:twince/services/backup_policy.dart';
import 'package:twince/widgets/export_backup_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Android authorizes Documents and stores the returned public URI',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    SharedPreferences.setMockInitialValues({});
    const channel = MethodChannel('twince/backup_folder');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return switch (call.method) {
        'prepare' => false,
        'authorize' => true,
        'create' => 'content://documents/Twince/new.json',
        _ => null,
      };
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final created =
        await BackupLibrary.instance.createNew(name: 'new', contents: '{}');
    expect(calls, ['prepare', 'authorize', 'create']);
    expect(created.sourceUri, 'content://documents/Twince/new.json');
    expect(
        (await BackupLibrary.instance.current())?.sourceUri, created.sourceUri);
  });

  test('Android cancelled access preserves the existing backup selection',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    SharedPreferences.setMockInitialValues({
      'twince_active_backup_name': 'old.json',
      'twince_active_backup_path': '/private/old.json',
    });
    const channel = MethodChannel('twince/backup_folder');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async => false);
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    await expectLater(BackupLibrary.instance.saveCurrent('{}'),
        throwsA(isA<BackupNameException>()));
    expect((await BackupLibrary.instance.current())?.path, '/private/old.json');
  });

  test(
      'Android save switches a legacy selection only after the public copy succeeds',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    SharedPreferences.setMockInitialValues({
      'twince_active_backup_name': 'old.json',
      'twince_active_backup_path': '/private/old.json',
    });
    const channel = MethodChannel('twince/backup_folder');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var fail = true;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'prepare') return true;
      if (fail) {
        throw PlatformException(code: 'STORAGE', message: 'Write failed');
      }
      expect((call.arguments as Map)['path'], '/private/old.json');
      return {'name': 'old (1).json', 'uri': 'content://documents/Twince/old'};
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    await expectLater(BackupLibrary.instance.saveCurrent('{}'),
        throwsA(isA<BackupNameException>()));
    expect((await BackupLibrary.instance.current())?.path, '/private/old.json');
    fail = false;
    expect((await BackupLibrary.instance.saveCurrent('{}')).saved, isTrue);
    final current = await BackupLibrary.instance.current();
    expect(current?.name, 'old (1).json');
    expect(current?.sourceUri, 'content://documents/Twince/old');
    expect(current?.path, isNull);
  });

  test('a failed backup creation preserves the current selection', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    SharedPreferences.setMockInitialValues({
      'twince_active_backup_name': 'existing.json',
      'twince_active_backup_path': '/existing.json',
    });
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'unavailable');
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    await expectLater(
      BackupLibrary.instance.createNew(name: 'new', contents: '{}'),
      throwsA(isA<BackupNameException>()),
    );
    final current = await BackupLibrary.instance.current();
    expect(current?.name, 'existing.json');
    expect(current?.path, '/existing.json');
  });

  test('saving the current backup updates its selected file', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final directory = await Directory.systemTemp.createTemp('twince-save');
    addTearDown(() => directory.delete(recursive: true));
    final file =
        File('${directory.path}${Platform.pathSeparator}selected.json');
    await file.writeAsString('old');
    SharedPreferences.setMockInitialValues({
      'twince_active_backup_name': 'selected.json',
      'twince_active_backup_path': file.path,
    });
    final result = await BackupLibrary.instance.saveCurrent('{"tasks":[]}');
    expect(result.saved, isTrue);
    expect(await file.readAsString(), '{"tasks":[]}');
    expect((await BackupLibrary.instance.current())?.path, file.path);
  });

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
    expect(find.text('Save to current backup'), findsNothing);
    expect(find.text('Create new backup'), findsNothing);
    expect(find.text('Current backup: none'), findsOneWidget);
    expect(find.text('Rename backup file'), findsOneWidget);
    Navigator.of(tester.element(find.text('Import backup'))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('پشتیبان‌گیری / Export Data'));
    await tester.pumpAndSettle();
    expect(find.text('Export data'), findsOneWidget);
    expect(find.text('Save to current backup'), findsOneWidget);
    expect(find.text('Create new backup'), findsOneWidget);
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
    final filename = tester.widget<Text>(find.text('Current backup: $name'));
    expect(filename.maxLines, 1);
    expect(filename.overflow, TextOverflow.ellipsis);
    Navigator.of(tester.element(find.text('Import backup'))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('پشتیبان‌گیری / Export Data'));
    await tester.pumpAndSettle();
    final save = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save to current backup'));
    expect(save.onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });
}
