import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:twince/models/task.dart';
import 'package:twince/screens/home_screen.dart';
import 'package:twince/screens/settings_screen.dart';
import 'package:twince/services/storage_service.dart';
import 'package:twince/theme/twince_theme.dart';

class _TaskStore extends ChangeNotifier implements StorageService {
  @override
  List<Task> getAllTasks() => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void _mockPackageInfo() {
  PackageInfo.setMockInitialValues(
    appName: 'Twince',
    packageName: 'com.twince.app',
    version: '2.3.4',
    buildNumber: '7',
    buildSignature: '',
  );
}

void main() {
  testWidgets('Settings sits left of Tasks and opens with the package version',
      (tester) async {
    _mockPackageInfo();
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<StorageService>.value(value: _TaskStore()),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final settingsCenter = tester.getCenter(find.text('Settings'));
    final tasksCenter = tester.getCenter(find.text('Tasks'));
    expect(settingsCenter.dx, lessThan(tasksCenter.dx));

    await tester.tap(find.text('Settings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('Version 2.3.4'), findsOneWidget);
    expect(find.text('© 2026. All rights reserved.'), findsOneWidget);

    await tester.tap(find.text('Tasks'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(SettingsScreen), findsNothing);
    expect(find.text('No active tasks yet'), findsOneWidget);
  });

  testWidgets('version and copyright fit a narrow screen', (tester) async {
    _mockPackageInfo();
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SettingsScreen())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Version 2.3.4'), findsOneWidget);
    expect(find.text('© 2026. All rights reserved.'), findsOneWidget);
    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Midnight'), findsOneWidget);
    expect(find.text('تغییر'), findsNothing);
    expect(
      tester.getCenter(find.text('Theme')).dy,
      lessThan(tester.getCenter(find.text('Settings')).dy),
    );
    final swatch = tester.widget<Container>(find.descendant(
      of: find.byKey(const ValueKey('midnight-theme-swatch')),
      matching: find.byType(Container),
    ));
    final swatchDecoration = swatch.decoration! as BoxDecoration;
    expect(swatchDecoration.color, TwinceThemeId.midnight.swatch);
    expect(swatchDecoration.shape, BoxShape.circle);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Midnight'));
    await tester.pumpAndSettle();
    expect(find.text('Theme'), findsWidgets);
    expect(find.byIcon(Icons.check_rounded), findsWidgets);
    await tester.tap(find.text('Midnight').last);
    await tester.pumpAndSettle();
    expect(find.text('Midnight'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
