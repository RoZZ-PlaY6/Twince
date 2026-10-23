import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<Directory> _backupDirectory() async {
  final root = await getApplicationDocumentsDirectory();
  final directory =
      Directory('${root.path}${Platform.pathSeparator}twince_backups');
  if (!await directory.exists()) {
    await directory.create(recursive: true);
  }
  return directory;
}

Future<String?> writeBackupCopy(String name, String contents) async {
  try {
    final directory = await _backupDirectory();
    final file = File('${directory.path}${Platform.pathSeparator}$name');
    await file.writeAsString(contents, flush: true);
    return file.path;
  } catch (_) {
    return null;
  }
}

Future<String?> renameBackupCopy(String? path, String newName) async {
  if (path == null || path.isEmpty) return null;
  try {
    final current = File(path);
    final next =
        File('${current.parent.path}${Platform.pathSeparator}$newName');
    if (!await current.exists()) return null;
    if (current.path == next.path) return current.path;
    if (await next.exists()) return null;
    final renamed = await current.rename(next.path);
    return renamed.path;
  } catch (_) {
    return null;
  }
}

Future<bool> writeExternalBackup(String path, String contents) async {
  try {
    final file = File(path);
    final parent = file.parent;
    if (!await parent.exists()) return false;
    await file.writeAsString(contents, flush: true);
    return true;
  } catch (_) {
    return false;
  }
}

Future<String?> readBackupCopy(String? path) async {
  if (path == null || path.isEmpty) return null;
  try {
    final file = File(path);
    if (!await file.exists()) return null;
    return await file.readAsString();
  } catch (_) {
    return null;
  }
}
