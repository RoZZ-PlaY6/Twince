import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twince/widgets/material_icon.dart';

void main() {
  test('web icon style uses the full icon font and the original code point',
      () {
    final style = MaterialIcon.glyphStyle(
      color: Colors.white,
      size: 20,
      web: true,
    );
    expect(style.fontFamily, MaterialIcon.webFontFamily);
    expect(style.fontFamilyFallback, contains(MaterialIcon.webFontFamily));
    expect(
      String.fromCharCode(Icons.settings_rounded.codePoint).runes.single,
      Icons.settings_rounded.codePoint,
    );
    expect(
      String.fromCharCode(Icons.settings_outlined.codePoint).runes.single,
      Icons.settings_outlined.codePoint,
    );
  });

  testWidgets('non-web icons stay on the framework icon widget',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: MaterialIcon(Icons.add_rounded, color: Colors.white),
      ),
    ));
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
