export 'import_service_stub.dart'
    if (dart.library.io) 'import_service_impl.dart'
    if (dart.library.html) 'import_service_web.dart';

enum ImportStatus { success, invalidFormat, noData, unavailable, cancelled }

class ImportResult {
  const ImportResult(
    this.status, {
    this.tasksImported = 0,
    this.recurringImported = 0,
    this.backupName,
    this.backupWritable = false,
  });
  final ImportStatus status;
  final int tasksImported;
  final int recurringImported;
  final String? backupName;
  final bool backupWritable;
}
