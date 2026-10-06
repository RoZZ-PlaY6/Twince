import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/recurring_task.dart';
import '../models/task.dart';
import 'import_service.dart';
import 'storage_service.dart';

class ImportService {
  ImportService._();
  static final instance = ImportService._();
  static const _channel = MethodChannel('twince/import');

  Future<ImportResult> importFromJson(StorageService storage, String jsonContent) async {
    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(jsonContent) as Map<String, dynamic>;
    } catch (e) {
      return const ImportResult(ImportStatus.invalidFormat);
    }

    // Validate schema version
    final schemaVersion = payload['schemaVersion'] as int?;
    if (schemaVersion == null || schemaVersion > 1) {
      return const ImportResult(ImportStatus.invalidFormat);
    }

    final hiveRecords = payload['hiveRecords'] as List?;
    if (hiveRecords == null || hiveRecords.isEmpty) {
      return const ImportResult(ImportStatus.noData);
    }

    int tasksImported = 0;
    int recurringImported = 0;

    try {
      // First, clear existing data
      await storage.clearAllData();

      // Import tasks and recurring tasks from hiveRecords
      for (final record in hiveRecords) {
        final box = record['box'] as String?;
        final type = record['type'] as String?;
        final key = record['key'] as String?;
        final value = record['value'] as Map<String, dynamic>?;

        if (box == null || type == null || key == null || value == null) {
          continue;
        }

        if (box == 'tasks' && type == 'Task') {
          try {
            final task = _jsonToTask(value);
            await storage.addTask(task);
            tasksImported++;
          } catch (e) {
            debugPrint('Failed to import task $key: $e');
          }
        } else if (box == 'recurring_tasks' && type == 'RecurringTask') {
          try {
            final recurringTask = _jsonToRecurringTask(value);
            await storage.addRecurringTask(recurringTask);
            recurringImported++;
          } catch (e) {
            debugPrint('Failed to import recurring task $key: $e');
          }
        }
      }

      // Regenerate recurring instances after import
      await storage.generateRecurringInstances();
      await storage.reconcile();

      return ImportResult(ImportStatus.success, tasksImported: tasksImported, recurringImported: recurringImported);
    } catch (e) {
      debugPrint('Import failed: $e');
      return const ImportResult(ImportStatus.invalidFormat);
    }
  }

  Future<ImportResult> pickAndImport(StorageService storage) async {
    try {
      final result = await _channel.invokeMethod<String>('pickAndReadFile', <String, dynamic>{
        'allowedExtensions': ['json'],
        'mimeType': 'application/json',
      });

      if (result == null || result.isEmpty) {
        return const ImportResult(ImportStatus.unavailable);
      }

      return await importFromJson(storage, result);
    } on PlatformException catch (e) {
      debugPrint('Platform exception during import: ${e.message}');
      return const ImportResult(ImportStatus.unavailable);
    } catch (e) {
      debugPrint('Import failed: $e');
      return const ImportResult(ImportStatus.invalidFormat);
    }
  }

  Task _jsonToTask(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      category: TaskCategoryX.fromString(json['category'] as String? ?? 'etc'),
      status: TaskStatus.values.byName(json['status'] as String? ?? 'pending'),
      isTimeBound: json['isTimeBound'] as bool? ?? true,
      targetDate: DateTime.parse(json['targetDate'] as String),
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      reminderIntervalMinutes: json['reminderIntervalMinutes'] as int? ?? 60,
      createdAt: DateTime.parse(json['createdAt'] as String),
      completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt'] as String) : null,
      recurringDefinitionId: json['recurringDefinitionId'] as String?,
      customNotificationMessage: json['customNotificationMessage'] as String?,
      notificationSoundId: json['notificationSoundId'] as String? ?? 'cyber_pulse',
      customSystemSoundUri: json['customSystemSoundUri'] as String?,
      notificationTimerOptions: (json['notificationTimerOptions'] as List?)
              ?.map((e) => NotificationTimerOption.values.byName(e as String))
              .toSet() ??
          const {},
    );
  }

  RecurringTask _jsonToRecurringTask(Map<String, dynamic> json) {
    return RecurringTask(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      category: TaskCategoryX.fromString(json['category'] as String? ?? 'etc'),
      weekdays: (json['weekdays'] as List?)?.cast<int>() ?? [],
      firstDate: DateTime.parse(json['firstDate'] as String),
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      isTimeBound: json['isTimeBound'] as bool? ?? true,
      reminderIntervalMinutes: json['reminderIntervalMinutes'] as int? ?? 60,
      createdAt: DateTime.parse(json['createdAt'] as String),
      generatedThrough: json['generatedThrough'] != null ? DateTime.parse(json['generatedThrough'] as String) : null,
      customNotificationMessage: json['customNotificationMessage'] as String?,
      notificationSoundId: json['notificationSoundId'] as String? ?? 'cyber_pulse',
      customSystemSoundUri: json['customSystemSoundUri'] as String?,
      notificationTimerOptions: (json['notificationTimerOptions'] as List?)
              ?.map((e) => NotificationTimerOption.values.byName(e as String))
              .toSet() ??
          const {},
    );
  }
}