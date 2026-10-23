class BackupNameException implements Exception {
  const BackupNameException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Turns a user-entered label into a single JSON file name.
String normalizeBackupName(String raw) {
  var name = raw.trim();
  if (name.isEmpty) {
    throw const BackupNameException('Enter a backup file name.');
  }
  name = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  if (name == '.' || name == '..' || name.contains('..')) {
    throw const BackupNameException('That file name is not allowed.');
  }
  if (!name.toLowerCase().endsWith('.json')) name = '$name.json';
  if (name == '.json') {
    throw const BackupNameException('Enter a backup file name.');
  }
  return name;
}

String timestampedBackupName(DateTime now) {
  final local = now.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return 'twince_backup_${local.year}${two(local.month)}${two(local.day)}_'
      '${two(local.hour)}${two(local.minute)}${two(local.second)}.json';
}
