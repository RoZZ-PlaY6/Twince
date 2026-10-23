import 'package:flutter_test/flutter_test.dart';
import 'package:twince/services/backup_policy.dart';

void main() {
  test('backup names stay as one json file', () {
    expect(normalizeBackupName('Semester'), 'Semester.json');
    expect(normalizeBackupName('Semester.JSON'), 'Semester.JSON');
    expect(
      normalizeBackupName(r'folder\my backup?.json'),
      'folder_my backup_.json',
    );
    expect(
      () => normalizeBackupName('..'),
      throwsA(isA<BackupNameException>()),
    );
    expect(
      () => normalizeBackupName('   '),
      throwsA(isA<BackupNameException>()),
    );
  });

  test('new backup names include the local time', () {
    expect(
      timestampedBackupName(DateTime.utc(2026, 10, 23, 5, 7, 8)),
      endsWith('.json'),
    );
  });
}
