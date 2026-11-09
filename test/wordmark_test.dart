import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:twince/models/task.dart';
import 'package:twince/screens/home_screen.dart';
import 'package:twince/services/storage_service.dart';

class _TaskStore extends ChangeNotifier implements StorageService {
  @override
  List<Task> getAllTasks() => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pumpHeader(
  WidgetTester tester, {
  required bool reduceMotion,
}) {
  return tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<StorageService>.value(value: _TaskStore()),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data:
              MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
          child: child!,
        ),
        home: const HomeScreen(),
      ),
    ),
  );
}

void main() {
  testWidgets('wordmark stays readable across the color cycle', (tester) async {
    await _pumpHeader(tester, reduceMotion: false);
    await tester.pump();
    expect(find.text('TWINCE'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 4500));
    expect(find.text('TWINCE'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(milliseconds: 4500));
    expect(find.text('TWINCE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion keeps a still wordmark', (tester) async {
    await _pumpHeader(tester, reduceMotion: true);
    await tester.pump();
    await tester.pump(const Duration(seconds: 12));
    expect(find.text('TWINCE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
