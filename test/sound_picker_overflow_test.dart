import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twince/services/sound_preview_service.dart';
import 'package:twince/widgets/sound_picker_field.dart';

void main() {
  testWidgets('selected notification sound fits title and subtitle',
      (tester) async {
    tester.view.physicalSize = const Size(614, 300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final sounds = await SoundPreviewService.instance.getAvailableSounds();
    final sound = sounds.firstWhere(
      (sound) => sound.name.contains('Atm Cash Machine'),
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SoundPickerField(
              label: 'Notification Sound',
              selectedSoundId: sound.id,
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(sound.name), findsOneWidget);
    expect(find.text(sound.description), findsWidgets);
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(DropdownButtonFormField<String>)).height,
        greaterThan(48));
  });
}
