import 'plan_service.dart';
import 'weekly_task_service.dart';

/// Weekly tasks and plans found in a backup.
///
/// A null list means that section was not in the file. An empty list means
/// the backup explicitly contains no records for that section.
class BackupSections {
  const BackupSections({
    this.weeklyTasks,
    this.plans,
    this.planOccurrences,
  });

  final List<WeeklyTask>? weeklyTasks;
  final List<PlanDefinition>? plans;
  final Map<String, String>? planOccurrences;

  static BackupSections read(Map<String, dynamic> payload) {
    final records = payload['hiveRecords'];
    final weeklyFromHive = <WeeklyTask>[];
    final plansFromHive = <PlanDefinition>[];
    final occurrencesFromHive = <String, String>{};
    var sawWeekly = false;
    var sawPlans = false;
    var sawOccurrences = false;
    if (records is List) {
      for (final raw in records) {
        if (raw is! Map) continue;
        final box = raw['box'];
        final key = raw['key'];
        final value = raw['value'];
        if (box == 'weekly_tasks' && value is Map) {
          sawWeekly = true;
          weeklyFromHive
              .add(WeeklyTask.fromJson(Map<String, dynamic>.from(value)));
        } else if (box == 'plan_definitions_v1' && value is Map) {
          sawPlans = true;
          plansFromHive
              .add(PlanDefinition.fromJson(Map<String, dynamic>.from(value)));
        } else if (box == 'plan_occurrences_v1' && key is String) {
          sawOccurrences = true;
          final taskId = value is Map
              ? value['taskId'] as String?
              : value is String
                  ? value
                  : null;
          if (taskId != null) occurrencesFromHive[key] = taskId;
        }
      }
    }
    return BackupSections(
      weeklyTasks:
          sawWeekly ? weeklyFromHive : _weeklyFromList(payload['weeklyTasks']),
      plans: sawPlans ? plansFromHive : _plansFromList(payload['plans']),
      planOccurrences: sawOccurrences
          ? occurrencesFromHive
          : _occurrencesFromList(payload['planOccurrences']),
    );
  }

  static List<WeeklyTask>? _weeklyFromList(Object? raw) {
    if (raw is! List) return null;
    return [
      for (final item in raw)
        if (item is Map) WeeklyTask.fromJson(Map<String, dynamic>.from(item)),
    ];
  }

  static List<PlanDefinition>? _plansFromList(Object? raw) {
    if (raw is! List) return null;
    return [
      for (final item in raw)
        if (item is Map)
          PlanDefinition.fromJson(Map<String, dynamic>.from(item)),
    ];
  }

  static Map<String, String>? _occurrencesFromList(Object? raw) {
    if (raw is! List) return null;
    return {
      for (final item in raw)
        if (item is Map && item['key'] is String && item['taskId'] is String)
          item['key'] as String: item['taskId'] as String,
    };
  }
}

Map<String, Object> weeklyHiveRecord(WeeklyTask task) => {
      'box': 'weekly_tasks',
      'type': 'WeeklyTask',
      'key': task.id,
      'value': task.toJson(),
    };

Map<String, Object> planHiveRecord(PlanDefinition plan) => {
      'box': 'plan_definitions_v1',
      'type': 'PlanDefinition',
      'key': plan.id,
      'value': plan.toJson(),
    };

Map<String, Object> planOccurrenceHiveRecord(String key, String taskId) => {
      'box': 'plan_occurrences_v1',
      'type': 'PlanOccurrence',
      'key': key,
      'value': {'taskId': taskId},
    };

/// Applies weekly tasks and plans when the backup contains those sections.
Future<void> restoreBackupSections(
  Map<String, dynamic> payload, {
  WeeklyTaskService? weeklyTasks,
  PlanService? plans,
}) async {
  final sections = BackupSections.read(payload);
  final weekly = sections.weeklyTasks;
  if (weekly != null && weeklyTasks != null) {
    await weeklyTasks.replaceAll(weekly);
  }
  final definitions = sections.plans;
  if (definitions != null && plans != null) {
    await plans.replaceAll(
      definitions,
      occurrences: sections.planOccurrences ?? const {},
    );
  }
}
