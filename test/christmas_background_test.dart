import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:ui' as ui;
import 'package:twince/theme/christmas_background.dart';

void main() {
  testWidgets('background animates without intercepting taps', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Stack(fit: StackFit.expand, children: [
        const ChristmasBackground(),
        Center(
            child:
                TextButton(onPressed: () => taps++, child: const Text('Tap'))),
      ]),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.tap(find.text('Tap'));
    expect(taps, 1);
    expect(find.byKey(const ValueKey('christmas-background')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('reduced motion stops the decorative animation', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: ChristmasBackground(),
      ),
    ));
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(find.byKey(const ValueKey('christmas-background')), findsOneWidget);
  });

  testWidgets('snow and lights both change between rendered frames',
      (tester) async {
    tester.view.physicalSize = const Size(240, 320);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: ChristmasBackground()));
    await tester.pump();

    Future<List<int>> capture() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(find
          .ancestor(
            of: find.byKey(const ValueKey('christmas-background')),
            matching: find.byType(RepaintBoundary),
          )
          .first);
      return (await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes =
            await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        image.dispose();
        return bytes!.buffer.asUint8List();
      }))!;
    }

    final before = await capture();
    await tester.pump(const Duration(seconds: 1));
    final after = await capture();
    const topBytes = 240 * 12 * 4;
    expect(
        before.take(topBytes).toList(), isNot(after.take(topBytes).toList()));
    expect(
        before.skip(topBytes).toList(), isNot(after.skip(topBytes).toList()));
    await tester.pumpWidget(const SizedBox());
  });
}
