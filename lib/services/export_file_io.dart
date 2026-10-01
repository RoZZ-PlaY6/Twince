import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<String?> writeExportFile(String fileName, String contents) async {
  final directory = await getTemporaryDirectory();
  final file = File('${directory.path}${Platform.pathSeparator}$fileName');
  await file.writeAsString(contents, flush: true);
  return file.path;
}
