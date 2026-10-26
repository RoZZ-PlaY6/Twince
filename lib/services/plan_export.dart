import 'dart:convert';

import 'plan_service.dart';

/// Raised when a plan cannot be exported without inventing data.
class PlanExportException implements Exception {
  const PlanExportException(this.message);
  final String message;

  @override
  String toString() => message;
}

const planExportDayKeys = [
  'mon',
  'tue',
  'wed',
  'thu',
  'fri',
  'sat',
  'sun',
];

/// Builds the Twince Alarm plan document from a stored [PlanDefinition].
///
/// This app stores a Z week as `weeks: odd` and an F week as `weeks: even`.
/// The export keeps that parity: Z is `weekType: odd`, F is `weekType: even`.
Map<String, Object?> buildPlanExport(
  PlanDefinition plan, {
  required DateTime exportedAt,
  required Duration timeZoneOffset,
}) {
  if (plan.id.trim().isEmpty) {
    throw const PlanExportException('This plan has no id.');
  }
  if (plan.name.trim().isEmpty) {
    throw const PlanExportException('This plan has no title.');
  }
  return {
    'format': 'twince-plan',
    'version': 1,
    'source': 'twince',
    'exportedAt': exportedAt.toUtc().toIso8601String(),
    'timezone': formatPlanOffset(timeZoneOffset),
    'plan': {
      'id': plan.id,
      'title': plan.name,
      'weekMode': plan.university ? 'even_odd' : 'every',
      'weekReference': {
        'evenLabel': 'F',
        'oddLabel': 'Z',
      },
      'tasks': [
        for (final entry in plan.entries) ...exportPlanTasks(entry),
      ],
    },
  };
}

String encodePlanExport(Map<String, Object?> document) {
  final encoded = const JsonEncoder.withIndent('  ').convert(document);
  final decoded = jsonDecode(encoded);
  if (decoded is! Map || decoded['format'] != 'twince-plan') {
    throw const PlanExportException('The plan export is not valid JSON.');
  }
  return encoded;
}

List<Map<String, Object?>> exportPlanTasks(PlanEntry entry) {
  if (entry.id.trim().isEmpty) {
    throw const PlanExportException('A plan task has no id.');
  }
  if (entry.title.trim().isEmpty) {
    throw PlanExportException('Plan task ${entry.id} has no title.');
  }
  if (entry.weekday < 1 || entry.weekday > 7) {
    throw PlanExportException('${entry.title} has no valid weekday.');
  }
  final endTime = formatPlanEndTime(entry.endSecond, entry.title);
  final day = planExportDayKeys[entry.weekday - 1];
  Map<String, Object?> task(String weekType, String weekLabel) => {
        'id': entry.id,
        'title': entry.title,
        'description': entry.description,
        'endTime': endTime,
        'days': [day],
        'weekType': weekType,
        'weekLabel': weekLabel,
        'enabled': true,
      };
  return switch (entry.weeks) {
    'odd' => [task('odd', 'Z')],
    'even' => [task('even', 'F')],
    'both' => [task('odd', 'Z'), task('even', 'F')],
    _ =>
      throw PlanExportException('${entry.title} has no Z/F week assignment.'),
  };
}

String formatPlanEndTime(int endSecond, String title) {
  if (endSecond < 0 || endSecond >= 24 * 3600) {
    throw PlanExportException('$title has no valid end time.');
  }
  final hour = endSecond ~/ 3600;
  final minute = (endSecond % 3600) ~/ 60;
  return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

String formatPlanOffset(Duration offset) {
  final sign = offset.isNegative ? '-' : '+';
  final absolute = offset.abs();
  final hours = absolute.inHours.toString().padLeft(2, '0');
  final minutes = (absolute.inMinutes % 60).toString().padLeft(2, '0');
  return '$sign$hours:$minutes';
}
