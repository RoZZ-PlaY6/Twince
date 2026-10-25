import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twince/screens/home_screen.dart';

void main() {
  test('web navigation uses BMP code points and Android keeps its icons', () {
    expect(
      navigationIconForPlatform(Icons.settings_rounded, web: false),
      Icons.settings_rounded,
    );
    expect(
      navigationIconForPlatform(Icons.task_alt_rounded, web: false),
      Icons.task_alt_rounded,
    );

    final webSettings =
        navigationIconForPlatform(Icons.settings_rounded, web: true);
    final webTasks =
        navigationIconForPlatform(Icons.task_alt_rounded, web: true);
    expect(webSettings.codePoint, lessThanOrEqualTo(0xFFFF));
    expect(webTasks.codePoint, lessThanOrEqualTo(0xFFFF));
    expect(webSettings, Icons.settings);
    expect(webTasks, Icons.task_alt);

    expect(
      navigationIconForPlatform(Icons.settings_outlined, web: true),
      Icons.settings_outlined,
    );
    expect(
      navigationIconForPlatform(Icons.date_range_rounded, web: true),
      Icons.date_range_rounded,
    );
    expect(
      navigationIconForPlatform(Icons.insights_outlined, web: true),
      Icons.insights_outlined,
    );
  });
}
