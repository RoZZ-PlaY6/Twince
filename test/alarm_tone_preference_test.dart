import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twince/models/task.dart';
import 'package:twince/screens/add_task_bottom_sheet.dart';
import 'package:twince/services/storage_service.dart';
import 'package:twince/services/user_preferences_service.dart';

void main() {
  final preferences = UserPreferencesService.instance;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await preferences.init();
  });

  setUp(() async {
    await preferences.clearLastAlarmSound();
  });

  test('remembers a built-in tone across a preferences reload', () async {
    expect(preferences.getLastAlarmSound(), isNull);

    await preferences.saveLastAlarmSound(const SavedAlarmPreference(
      type: AlarmSoundType.builtIn,
      soundId: 'gentle_bell',
    ));
    await preferences.saveLastAlarmSound(const SavedAlarmPreference(
      type: AlarmSoundType.customFile,
      soundId: 'song',
      uri: 'content://alarm/song',
    ));
    await preferences.saveLastAlarmSound(const SavedAlarmPreference(
      type: AlarmSoundType.builtIn,
      soundId: 'subtle_beep',
    ));
    await preferences.init();

    final saved = preferences.getLastAlarmSound();
    expect(saved?.type, AlarmSoundType.builtIn);
    expect(saved?.soundId, 'subtle_beep');
    expect(saved?.uri, isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('last_alarm_sound_uri'), isNull);
  });

  test('unavailable saved tones fall back without being replaced', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_alarm_sound_type', 'builtIn');
    await prefs.setString('last_alarm_sound_id', 'removed_tone');
    expect(preferences.getLastAlarmSound(), isNull);
    expect(prefs.getString('last_alarm_sound_id'), 'removed_tone');

    await preferences.saveLastAlarmSound(const SavedAlarmPreference(
      type: AlarmSoundType.builtIn,
      soundId: 'also_missing',
    ));
    expect(prefs.getString('last_alarm_sound_id'), 'removed_tone');

    await prefs.setString('last_alarm_sound_type', 'retired');
    expect(preferences.getLastAlarmSound(), isNull);
  });

  testWidgets('new alarmed tasks preselect the last in-app tone',
      (tester) async {
    final previousErrorHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('ListTile background color')) {
        return;
      }
      previousErrorHandler?.call(details);
    };
    addTearDown(() => FlutterError.onError = previousErrorHandler);
    tester.view.physicalSize = const Size(420, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final storage = _PreferenceStorage();

    var generation = 0;
    Future<void> openNew() async {
      generation += 1;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AddTaskBottomSheet(
            key: ValueKey('new-$generation'),
            storage: storage,
            initialAlarmEnabled: true,
          ),
        ),
      ));
      await tester.scrollUntilVisible(
        find.text('App'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
    }

    await openNew();
    expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'System'))
            .selected,
        isTrue);
    expect(find.text('Cyber Pulse'), findsNothing);

    await tester.tap(find.text('App'));
    await tester.pump();
    expect(find.text('Cyber Pulse'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('cyber_pulse')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Gentle Bell').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await openNew();
    expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'App'))
            .selected,
        isTrue);
    expect(
        tester
            .widget<DropdownButtonFormField<String>>(
                find.byKey(const ValueKey('gentle_bell')))
            .initialValue,
        'gentle_bell');
    expect(preferences.getLastAlarmSound()?.soundId, 'gentle_bell');

    await preferences.init();
    await openNew();
    expect(
        tester
            .widget<DropdownButtonFormField<String>>(
                find.byKey(const ValueKey('gentle_bell')))
            .initialValue,
        'gentle_bell');

    final existing = Task(
      id: 'kept-tone',
      title: 'Existing alarm',
      targetDate: DateTime(2026, 10, 23),
      startTime: DateTime(2026, 10, 23, 9),
      endTime: DateTime(2026, 10, 23, 10),
      isAlarm: true,
      alarmSoundType: AlarmSoundType.builtIn,
      alarmSoundId: 'subtle_beep',
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AddTaskBottomSheet(
          key: const ValueKey('edit-existing'),
          storage: storage,
          task: existing,
        ),
      ),
    ));
    await tester.scrollUntilVisible(
      find.text('Built-in sound'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
        tester
            .widget<DropdownButtonFormField<String>>(
                find.byKey(const ValueKey('subtle_beep')))
            .initialValue,
        'subtle_beep');
    expect(find.byKey(const ValueKey('gentle_bell')), findsNothing);
    expect(existing.alarmSoundId, 'subtle_beep');
    expect(preferences.getLastAlarmSound()?.soundId, 'gentle_bell');

    final plain = Task(
      id: 'plain',
      title: 'No alarm',
      targetDate: DateTime(2026, 10, 23),
      startTime: DateTime(2026, 10, 23, 9),
      endTime: DateTime(2026, 10, 23, 10),
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AddTaskBottomSheet(
          key: const ValueKey('plain-task'),
          storage: storage,
          task: plain,
        ),
      ),
    ));
    expect(find.text('Alarm sound source'), findsNothing);
    expect(plain.isAlarm, isFalse);
    expect(preferences.getLastAlarmSound()?.soundId, 'gentle_bell');
  });
}

class _PreferenceStorage extends ChangeNotifier implements StorageService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
