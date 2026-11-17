import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twince/widgets/history_record_icon.dart';

void main() {
  testWidgets('history record icon follows the app bar icon size',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: ColoredBox(
          color: Color(0xFF030A19),
          child: SizedBox(
            width: 96,
            height: 48,
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Icon(Icons.restore_outlined, color: Color(0xFF06B6D4)),
                  HistoryRecordIcon(color: Color(0xFF06B6D4)),
                ]),
          ),
        ),
      ),
    ));
    expect(tester.getSize(find.byType(HistoryRecordIcon)), const Size(24, 24));
    expect(find.byIcon(Icons.restore_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
