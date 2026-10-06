import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/recurring_task.dart';
import '../models/task.dart';
import 'export_file.dart';
import 'storage_service.dart';

enum ExportStatus { shared, noData, unavailable }

class ExportResult {
  const ExportResult(this.status);
  final ExportStatus status;
}

class ExportService {
  ExportService._();
  static final instance = ExportService._();
  static const _channel = MethodChannel('twince/export');

  Future<ExportResult> exportAndShare(StorageService storage) async {
    final tasks = storage.getAllTasks();
    final recurringDefinitions = storage.getRecurringTasks();
    if (tasks.isEmpty && recurringDefinitions.isEmpty) {
      return const ExportResult(ExportStatus.noData);
    }

    final taskMaps = tasks.map(_taskToJson).toList(growable: false);
    final recurringMaps =
        recurringDefinitions.map(_recurringToJson).toList(growable: false);
    final payload = <String, dynamic>{
      'schemaVersion': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'tasks': taskMaps,
      'completedTasks': taskMaps
          .where((task) => task['status'] == TaskStatus.completed.name)
          .toList(growable: false),
      'recurringDefinitions': recurringMaps,
      'hiveRecords': [
        ...taskMaps.map((value) => {
              'box': 'tasks',
              'type': 'Task',
              'key': value['id'],
              'value': value,
            }),
        ...recurringMaps.map((value) => {
              'box': 'recurring_tasks',
              'type': 'RecurringTask',
              'key': value['id'],
              'value': value,
            }),
      ],
      // The current app stores user preferences on task and recurring records.
      // Keep this explicit so future settings boxes can be added without changing
      // the export schema.
      'settings': <String, dynamic>{},
      'notificationPreferences': {
        'tasks': tasks.map(_notificationPreferences).toList(growable: false),
        'recurringDefinitions': recurringDefinitions
            .map(_recurringNotificationPreferences)
            .toList(growable: false),
      },
    };

    final contents = const JsonEncoder.withIndent('  ').convert(payload);
    final fileName =
        'twince_backup_${DateTime.now().toIso8601String().replaceAll(':', '-')}.json';
    final path = await writeExportFile(fileName, contents);
    if (path == null || kIsWeb)
      return const ExportResult(ExportStatus.unavailable);

    await _channel.invokeMethod<void>('shareFile', <String, dynamic>{
      'path': path,
      'fileName': fileName,
      'mimeType': 'application/json',
      'title': 'Twince backup',
    });
    return const ExportResult(ExportStatus.shared);
  }

  Map<String, dynamic> _taskToJson(Task task) => {
        'id': task.id,
        'title': task.title,
        'description': task.description,
        'category': task.category.name,
        'status': task.status.name,
        'isTimeBound': task.isTimeBound,
        'targetDate': task.targetDate.toIso8601String(),
        'startTime': task.startTime.toIso8601String(),
        'endTime': task.endTime.toIso8601String(),
        'reminderIntervalMinutes': task.reminderIntervalMinutes,
        'createdAt': task.createdAt.toIso8601String(),
        'completedAt': task.completedAt?.toIso8601String(),
        'recurringDefinitionId': task.recurringDefinitionId,
        'customNotificationMessage': task.customNotificationMessage,
        'notificationSoundId': task.notificationSoundId,
        'customSystemSoundUri': task.customSystemSoundUri,
        'notificationTimerOptions':
            task.notificationTimerOptions.map((option) => option.name).toList(),
        'isAlarm': task.isAlarm,
        'alarmSoundType': task.alarmSoundType.name,
        'alarmSoundId': task.alarmSoundId,
        'alarmSoundUri': task.alarmSoundUri,
      };

  Map<String, dynamic> _recurringToJson(RecurringTask task) => {
        'id': task.id,
        'title': task.title,
        'description': task.description,
        'category': task.category.name,
        'weekdays': task.weekdays,
        'firstDate': task.firstDate.toIso8601String(),
        'startTime': task.startTime.toIso8601String(),
        'endTime': task.endTime.toIso8601String(),
        'isTimeBound': task.isTimeBound,
        'reminderIntervalMinutes': task.reminderIntervalMinutes,
        'createdAt': task.createdAt.toIso8601String(),
        'generatedThrough': task.generatedThrough?.toIso8601String(),
        'customNotificationMessage': task.customNotificationMessage,
        'notificationSoundId': task.notificationSoundId,
        'customSystemSoundUri': task.customSystemSoundUri,
        'notificationTimerOptions':
            task.notificationTimerOptions.map((option) => option.name).toList(),
        'isAlarm': task.isAlarm,
        'alarmSoundType': task.alarmSoundType.name,
        'alarmSoundId': task.alarmSoundId,
        'alarmSoundUri': task.alarmSoundUri,
      };

  Map<String, dynamic> _notificationPreferences(Task task) => {
        'taskId': task.id,
        'soundId': task.notificationSoundId,
        'customSystemSoundUri': task.customSystemSoundUri,
        'timerOptions':
            task.notificationTimerOptions.map((option) => option.name).toList(),
        'customMessage': task.customNotificationMessage,
        'isAlarm': task.isAlarm,
        'alarmSoundType': task.alarmSoundType.name,
        'alarmSoundId': task.alarmSoundId,
        'alarmSoundUri': task.alarmSoundUri,
      };

  Map<String, dynamic> _recurringNotificationPreferences(RecurringTask task) =>
      {
        'recurringDefinitionId': task.id,
        'soundId': task.notificationSoundId,
        'customSystemSoundUri': task.customSystemSoundUri,
        'timerOptions':
            task.notificationTimerOptions.map((option) => option.name).toList(),
        'customMessage': task.customNotificationMessage,
        'isAlarm': task.isAlarm,
        'alarmSoundType': task.alarmSoundType.name,
        'alarmSoundId': task.alarmSoundId,
        'alarmSoundUri': task.alarmSoundUri,
      };
}
