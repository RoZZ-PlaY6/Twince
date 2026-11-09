import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twince/screens/plan_screen.dart';
import 'package:twince/screens/home_screen.dart';
import 'package:twince/services/plan_service.dart';
import 'package:twince/services/storage_service.dart';
import 'package:twince/models/task.dart';
import 'package:twince/screens/settings_screen.dart';
import 'package:twince/services/week_cycle_service.dart';

void main() {
  late SharedPreferences prefs;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  setUp(() async {
    await prefs.clear();
  });

  test('canonical labels and stored parity agree for Even Z and Odd F',
      () async {
    final cycle = WeekCycleService(prefs);
    for (final parity in WeekParity.values) {
      await cycle.chooseCurrentWeek(parity.isOdd, now: DateTime(2026, 12, 31));
      expect(cycle.anchorSaturday, DateTime(2026, 12, 26));
      expect(WeekParity.fromStorage(parity.storageValue), parity);
      expect(WeekParity.fromOdd(cycle.isOddOn(DateTime(2026, 12, 31))), parity);
      expect(cycle.currentWeekLabel(DateTime(2026, 12, 31)),
          parity.persianCurrentLabel);
      expect(parity.englishCurrentLabel,
          parity.isOdd ? 'Current week: Odd (F)' : 'Current week: Even (Z)');
      final restored = WeekCycleService(prefs);
      expect(restored.isOddOn(DateTime(2027, 1, 1)), parity.isOdd);
      expect(restored.isOddOn(DateTime(2027, 1, 2)), !parity.isOdd);
      expect(restored.isOddOn(DateTime(2026, 12, 19)), !parity.isOdd);
      expect(restored.isOddOn(DateTime(2026, 12, 12)), parity.isOdd);
      expect(restored.isOddOn(DateTime(2027, 1, 9)), parity.isOdd);
    }
  });
  test('weeks start on Saturday and ignore the time of day', () {
    final saturday = DateTime(2026, 10, 24, 23, 30);
    final friday = DateTime(2026, 10, 30, 23, 59);
    final nextSaturday = DateTime(2026, 10, 31, 0, 5);
    expect(saturday.weekday, DateTime.saturday);
    expect(saturdayStartingWeek(saturday), DateTime(2026, 10, 24));
    expect(saturdayStartingWeek(DateTime(2026, 10, 27, 15)),
        DateTime(2026, 10, 24));
    expect(saturdayStartingWeek(friday), DateTime(2026, 10, 24));
    expect(saturdayStartingWeek(nextSaturday), DateTime(2026, 10, 31));
    expect(
        elapsedSaturdayWeeks(DateTime(2026, 1, 3), DateTime(2026, 1, 24, 23)),
        3);
  });

  test('even elapsed weeks keep the anchor type and odd weeks toggle it',
      () async {
    final cycle = WeekCycleService(prefs);
    await cycle.chooseCurrentWeek(true, now: DateTime(2026, 10, 27, 18));
    expect(cycle.anchorSaturday, DateTime(2026, 10, 24));
    expect(cycle.isOddOn(DateTime(2026, 10, 24)), isTrue);
    expect(cycle.isOddOn(DateTime(2026, 10, 30, 23, 59)), isTrue);
    expect(cycle.isOddOn(DateTime(2026, 10, 31)), isFalse);
    expect(cycle.isOddOn(DateTime(2026, 11, 7)), isTrue);
    expect(cycle.isOddOn(DateTime(2026, 11, 14)), isFalse);

    final restored = WeekCycleService(prefs);
    expect(restored.isConfigured, isTrue);
    expect(restored.anchorOdd, isTrue);
    expect(restored.isOddOn(DateTime(2026, 10, 31, 12)), isFalse);
    expect(restored.currentWeekLabel(DateTime(2026, 10, 27)),
        'هفته جاری: فرد (F)');
    expect(restored.currentWeekLabel(DateTime(2026, 10, 31)),
        'هفته جاری: زوج (Z)');
  });

  test(
      'selection on Saturday Sunday and Friday stays fixed until the next Saturday',
      () async {
    for (final selectedDay in [
      DateTime(2026, 10, 24, 23, 50),
      DateTime(2026, 10, 25, 13),
      DateTime(2026, 10, 30, 23, 59, 59),
    ]) {
      for (final odd in [false, true]) {
        await prefs.clear();
        final cycle = WeekCycleService(prefs);
        await cycle.chooseCurrentWeek(odd, now: selectedDay);
        expect(cycle.anchorSaturday, DateTime(2026, 10, 24));
        for (final day in [24, 25, 26, 30]) {
          expect(cycle.isOddOn(DateTime(2026, 10, day, 23)), odd);
        }
        expect(cycle.isOddOn(DateTime(2026, 10, 31)), !odd);
        expect(cycle.isOddOn(DateTime(2026, 11, 7)), odd);
        expect(cycle.isOddOn(DateTime(2026, 10, 17)), !odd);
        final reloaded = WeekCycleService(prefs);
        expect(reloaded.isOddOn(DateTime(2026, 10, 30)), odd);
        expect(reloaded.isOddOn(DateTime(2026, 10, 31)), !odd);
      }
    }
  });

  test('reselecting resets the Saturday anchor and survives a reload',
      () async {
    final cycle = WeekCycleService(prefs);
    await cycle.chooseCurrentWeek(false, now: DateTime(2026, 10, 24, 22));
    expect(cycle.isOddOn(DateTime(2026, 10, 31)), isTrue);
    await cycle.chooseCurrentWeek(false, now: DateTime(2026, 10, 31, 15));
    expect(cycle.anchorSaturday, DateTime(2026, 10, 31));
    expect(cycle.isOddOn(DateTime(2026, 10, 31)), isFalse);
    expect(cycle.isOddOn(DateTime(2026, 11, 6, 23, 59)), isFalse);
    expect(cycle.isOddOn(DateTime(2026, 11, 7)), isTrue);
    final reloaded = WeekCycleService(prefs);
    expect(reloaded.anchorOdd, isFalse);
    expect(reloaded.anchorSaturday, DateTime(2026, 10, 31));
    expect(reloaded.isOddOn(DateTime(2026, 11, 6)), isFalse);
    expect(reloaded.isOddOn(DateTime(2026, 11, 7)), isTrue);
  });

  test('previously saved parity values keep their scheduling meaning',
      () async {
    await prefs.setBool(WeekCycleService.configuredKey, true);
    await prefs.setString(WeekCycleService.anchorKey, '2026-10-24');
    await prefs.setBool(WeekCycleService.anchorOddKey, true);
    final cycle = WeekCycleService(prefs);
    expect(cycle.isOddOn(DateTime(2026, 10, 30)), isTrue);
    expect(
        cycle.currentWeekLabel(DateTime(2026, 10, 30)), 'هفته جاری: فرد (F)');
    expect(
        planEntryRunsThisWeek(
            everyWeek: false,
            weeks: 'odd',
            oddWeek: cycle.isOddOn(DateTime(2026, 10, 30))),
        isTrue);
    expect(prefs.getBool(WeekCycleService.anchorOddKey), isTrue);
  });
  test('an incomplete saved anchor requires a fresh explicit choice', () async {
    await prefs.setBool(WeekCycleService.configuredKey, true);
    await prefs.setString(WeekCycleService.anchorKey, '2026-10-26');
    await prefs.setBool(WeekCycleService.anchorOddKey, false);
    expect(WeekCycleService(prefs).isConfigured, isFalse);
    await prefs.setString(WeekCycleService.anchorKey, '2026-10-24');
    await prefs.remove(WeekCycleService.anchorOddKey);
    expect(WeekCycleService(prefs).isConfigured, isFalse);
  });
  test('plan entries follow odd F, even Z, both, and every week', () {
    expect(
      planEntryRunsThisWeek(everyWeek: false, weeks: 'odd', oddWeek: true),
      isTrue,
    );
    expect(
      planEntryRunsThisWeek(everyWeek: false, weeks: 'even', oddWeek: true),
      isFalse,
    );
    expect(
      planEntryRunsThisWeek(everyWeek: false, weeks: 'both', oddWeek: false),
      isTrue,
    );
    expect(
      planEntryRunsThisWeek(everyWeek: false, weeks: 'even', oddWeek: false),
      isTrue,
    );
    expect(
      planEntryRunsThisWeek(everyWeek: true, weeks: 'both', oddWeek: false),
      isTrue,
    );
    expect(
      planEntryRunsThisWeek(everyWeek: true, weeks: 'odd', oddWeek: false),
      isFalse,
    );
    expect(
      planEntryRunsThisWeek(everyWeek: true, weeks: 'even', oddWeek: false),
      isTrue,
    );
  });

  test('reset removes the saved week so setup is required again', () async {
    final cycle = WeekCycleService(prefs);
    await cycle.chooseCurrentWeek(false, now: DateTime(2026, 10, 27));
    await cycle.reset();
    expect(cycle.isConfigured, isFalse);
    expect(cycle.anchorSaturday, isNull);
    expect(
        () => cycle.currentWeekLabel(DateTime(2026, 10, 27)), throwsStateError);
    await cycle.chooseCurrentWeek(WeekParity.even.isOdd,
        now: DateTime(2026, 10, 27));
    expect(
        cycle.currentWeekLabel(DateTime(2026, 10, 27)), 'هفته جاری: زوج (Z)');
  });

  testWidgets('Plan asks for the week on entry and then shows the banner',
      (tester) async {
    final cycle = WeekCycleService(prefs);
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: cycle,
      child: MaterialApp(
        home: Scaffold(
          body: PlanWeekPrompt(
            child: Builder(builder: (context) {
              final current = context.watch<WeekCycleService>();
              return Column(children: [
                if (current.isConfigured) PlanWeekBanner(cycle: current),
                const Text('plan list'),
              ]);
            }),
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('هفته جاری را انتخاب کنید'), findsOneWidget);
    expect(find.text('انصراف'), findsNothing);
    expect(find.text('plan list'), findsOneWidget);

    await tester.tap(find.text('هفته زوج (Z)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Current week: Even (Z)'), findsOneWidget);
    expect(find.byIcon(Icons.swap_horiz_rounded), findsNothing);
    expect(find.byTooltip('Change week'), findsOneWidget);
    expect(cycle.anchorSaturday, saturdayStartingWeek(DateTime.now()));

    await tester.tap(find.byTooltip('Change week'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('هفته فرد (F)'), findsOneWidget);
    expect(find.text('هفته زوج (Z)'), findsOneWidget);

    await tester.tap(find.text('هفته فرد (F)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Current week: Odd (F)'), findsOneWidget);
    expect(find.byIcon(Icons.swap_horiz_rounded), findsNothing);
    expect(cycle.isOddOn(DateTime.now()), isTrue);

    await tester.tap(find.byTooltip('Change week'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('بازنشانی'));
    await tester.pumpAndSettle();
    expect(find.text('Current week: Odd (F)'), findsOneWidget);
    expect(cycle.anchorSaturday, saturdayStartingWeek(DateTime.now()));
  });

  testWidgets(
      'Home navigation renders Plan and Settings labels from saved parity',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final plans = _PlanStore();
    final tasks = _TaskStore();
    Future<void> mount(WeekCycleService cycle) => tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<WeekCycleService>.value(value: cycle),
              ChangeNotifierProvider<PlanService>.value(value: plans),
              ChangeNotifierProvider<StorageService>.value(value: tasks),
            ],
            child: const MaterialApp(home: HomeScreen()),
          ),
        );

    final cycle = WeekCycleService(prefs);
    await cycle.chooseCurrentWeek(WeekParity.even.isOdd, now: DateTime.now());
    await mount(cycle);
    await tester.tap(find.text('Plan'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Current week: Even (Z)'), findsOneWidget);
    await tester.tap(find.byTooltip('Change week'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('هفته زوج (Z)'), findsOneWidget);
    expect(find.text('هفته فرد (F)'), findsOneWidget);
    await tester.tap(find.text('هفته فرد (F)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Current week: Odd (F)'), findsOneWidget);
    expect(cycle.isOddOn(DateTime.now()), isTrue);

    await tester.tap(find.text('Settings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('هفته جاری: فرد (F)'), findsNothing);
    expect(find.text('تغییر'), findsNothing);
    expect(find.text('Settings'), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    final restored = WeekCycleService(prefs);
    expect(restored.anchorSaturday, saturdayStartingWeek(DateTime.now()));
    expect(restored.isOddOn(DateTime.now()), isTrue);
    await mount(restored);
    await tester.tap(find.text('Plan'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Current week: Odd (F)'), findsOneWidget);
    await tester.tap(find.byTooltip('Change week'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('هفته زوج (Z)'), findsOneWidget);
    expect(find.text('هفته فرد (F)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('settings does not show or change the current week',
      (tester) async {
    final cycle = WeekCycleService(prefs);
    await cycle.chooseCurrentWeek(true, now: DateTime.now());
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: cycle,
      child: const MaterialApp(home: Scaffold(body: SettingsScreen())),
    ));
    await tester.pump();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('هفته جاری: فرد (F)'), findsNothing);
    expect(find.text('تغییر'), findsNothing);
    expect(cycle.isOddOn(DateTime.now()), isTrue);
    expect(tester.takeException(), isNull);
  });
}

class _TaskStore extends ChangeNotifier implements StorageService {
  @override
  List<Task> getAllTasks() => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PlanStore extends ChangeNotifier implements PlanService {
  @override
  List<PlanDefinition> get plans => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
