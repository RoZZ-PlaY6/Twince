import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twince/screens/plan_screen.dart';
import 'package:twince/theme/app_theme.dart';

void main() {
  testWidgets('Plan chooser and University template editor fit a phone',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: Builder(
            builder: (context) => TextButton(
                  onPressed: () => showAddPlanFlow(context),
                  child: const Text('Open plans'),
                )),
      ),
    ));
    await tester.tap(find.text('Open plans'));
    await tester.pumpAndSettle();
    expect(find.text('University'), findsOneWidget);
    expect(find.text('ETC'), findsOneWidget);
    await tester.tap(find.text('University'));
    await tester.pumpAndSettle();
    expect(find.text('Add University Plan'), findsOneWidget);
    await tester.tap(find.text('Add task to day'));
    await tester.pumpAndSettle();
    expect(find.text('Day of week'), findsOneWidget);
    expect(find.text('Weeks'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
