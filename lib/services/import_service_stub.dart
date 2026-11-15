import 'import_service.dart';
import 'plan_service.dart';
import 'storage_service.dart';
import 'weekly_task_service.dart';

class ImportService {
  ImportService._();
  static final instance = ImportService._();

  Future<ImportResult> importFromJson(
    StorageService storage,
    String jsonContent, {
    WeeklyTaskService? weeklyTasks,
    PlanService? plans,
  }) async {
    return const ImportResult(ImportStatus.unavailable);
  }

  Future<ImportResult> pickAndImport(
    StorageService storage, {
    WeeklyTaskService? weeklyTasks,
    PlanService? plans,
  }) async {
    return const ImportResult(ImportStatus.unavailable);
  }
}
