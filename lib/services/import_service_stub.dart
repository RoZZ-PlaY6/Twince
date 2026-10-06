import 'import_service.dart';
import 'storage_service.dart';

class ImportService {
  ImportService._();
  static final instance = ImportService._();

  Future<ImportResult> importFromJson(StorageService storage, String jsonContent) async {
    return const ImportResult(ImportStatus.unavailable);
  }

  Future<ImportResult> pickAndImport(StorageService storage) async {
    return const ImportResult(ImportStatus.unavailable);
  }
}