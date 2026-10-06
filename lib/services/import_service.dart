export 'import_service_stub.dart'
    if (dart.library.io) 'import_service_impl.dart'
    if (dart.library.html) 'import_service_web.dart';

enum ImportStatus { success, invalidFormat, noData, unavailable }

class ImportResult {
  const ImportResult(this.status,
      {this.tasksImported = 0, this.recurringImported = 0});
  final ImportStatus status;
  final int tasksImported;
  final int recurringImported;
}
