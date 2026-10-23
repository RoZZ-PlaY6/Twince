import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/task.dart';
import 'storage_service.dart';

/// A template belongs to a plan; generated tasks remain independent Task records.
class PlanEntry {
  const PlanEntry({
    required this.id,
    required this.title,
    required this.description,
    required this.weekday,
    required this.weeks,
    required this.startSecond,
    required this.endSecond,
    required this.reminderMinutes,
    this.taskOptions = const {},
  });

  final String id;
  final String title;
  final String description;
  final int weekday;
  final String weeks; // odd, even, or both
  final int startSecond;
  final int endSecond;
  final int reminderMinutes;
  final Map<String, dynamic> taskOptions;

  factory PlanEntry.fromTask(
    Task task, {
    required String id,
    required int weekday,
    required String weeks,
  }) =>
      PlanEntry(
        id: id,
        title: task.title,
        description: task.description,
        weekday: weekday,
        weeks: weeks,
        startSecond: task.startTime.hour * 3600 +
            task.startTime.minute * 60 +
            task.startTime.second,
        endSecond: task.endTime.hour * 3600 +
            task.endTime.minute * 60 +
            task.endTime.second,
        reminderMinutes: task.reminderIntervalMinutes,
        taskOptions: {
          'category': task.category.name,
          'isTimeBound': task.isTimeBound,
          'customNotificationMessage': task.customNotificationMessage,
          'notificationSoundId': task.notificationSoundId,
          'customSystemSoundUri': task.customSystemSoundUri,
          'notificationTimerOptions': task.notificationTimerOptions
              .map((option) => option.name)
              .toList(),
          'isAlarm': task.isAlarm,
          'alarmSoundType': task.alarmSoundType.name,
          'alarmSoundId': task.alarmSoundId,
          'alarmSoundUri': task.alarmSoundUri,
        },
      );

  Task taskOn(DateTime day, {required String id}) {
    final start = day.add(Duration(seconds: startSecond));
    var end = day.add(Duration(seconds: endSecond));
    if (!end.isAfter(start)) end = end.add(const Duration(days: 1));
    final options = taskOptions;
    return Task(
      id: id,
      title: title,
      description: description,
      category:
          TaskCategoryX.fromString(options['category'] as String? ?? 'etc'),
      isTimeBound: options['isTimeBound'] as bool? ?? true,
      targetDate: day,
      startTime: start,
      endTime: end,
      reminderIntervalMinutes: reminderMinutes,
      customNotificationMessage:
          options['customNotificationMessage'] as String?,
      notificationSoundId:
          options['notificationSoundId'] as String? ?? 'cyber_pulse',
      customSystemSoundUri: options['customSystemSoundUri'] as String?,
      notificationTimerOptions: (options['notificationTimerOptions'] as List?)
              ?.map((value) =>
                  NotificationTimerOption.values.byName(value as String))
              .toSet() ??
          <NotificationTimerOption>{},
      isAlarm: options['isAlarm'] as bool? ?? false,
      alarmSoundType: AlarmSoundType.values
          .byName(options['alarmSoundType'] as String? ?? 'system'),
      alarmSoundId: options['alarmSoundId'] as String? ?? 'cyber_pulse',
      alarmSoundUri: options['alarmSoundUri'] as String?,
    );
  }

  Map<String, Object> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'weekday': weekday,
        'weeks': weeks,
        'startSecond': startSecond,
        'endSecond': endSecond,
        'reminderMinutes': reminderMinutes,
        'taskOptions': taskOptions,
      };

  factory PlanEntry.fromJson(Map<String, dynamic> json) => PlanEntry(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        weekday: json['weekday'] as int,
        weeks: json['weeks'] as String,
        startSecond: json['startSecond'] as int,
        endSecond: json['endSecond'] as int,
        reminderMinutes: json['reminderMinutes'] as int,
        taskOptions: Map<String, dynamic>.from(
            json['taskOptions'] as Map? ?? const <String, dynamic>{}),
      );
}

class PlanDefinition {
  const PlanDefinition({
    required this.id,
    required this.name,
    required this.university,
    required this.anchorMonday,
    required this.anchorOdd,
    required this.entries,
  });

  final String id;
  final String name;
  final bool university;
  final DateTime anchorMonday;
  final bool anchorOdd;
  final List<PlanEntry> entries;

  bool isOddOn(DateTime date) {
    final monday = DateTime(date.year, date.month, date.day)
        .subtract(Duration(days: date.weekday - 1));
    final weeks = monday.difference(anchorMonday).inDays ~/ 7;
    return weeks.isEven ? anchorOdd : !anchorOdd;
  }

  PlanDefinition withCurrentWeek(bool odd, DateTime now) => PlanDefinition(
        id: id,
        name: name,
        university: university,
        anchorMonday: DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1)),
        anchorOdd: odd,
        entries: entries,
      );

  Map<String, Object> toJson() => {
        'id': id,
        'name': name,
        'university': university,
        'anchorMonday': anchorMonday.toIso8601String(),
        'anchorOdd': anchorOdd,
        'entries': entries.map((entry) => entry.toJson()).toList(),
      };

  factory PlanDefinition.fromJson(Map<String, dynamic> json) => PlanDefinition(
        id: json['id'] as String,
        name: json['name'] as String,
        university: json['university'] as bool,
        anchorMonday: DateTime.parse(json['anchorMonday'] as String),
        anchorOdd: json['anchorOdd'] as bool,
        entries: (json['entries'] as List)
            .map((entry) =>
                PlanEntry.fromJson(Map<String, dynamic>.from(entry as Map)))
            .toList(),
      );
}

/// Plan definitions live outside Task/RecurringTask boxes and need no adapter.
class PlanService extends ChangeNotifier {
  PlanService._(this._plans, this._generated, this._tasks);

  final Box<String> _plans;
  final Box<String> _generated;
  final StorageService _tasks;
  Timer? _timer;
  bool _generating = false;

  static Future<PlanService> initialize(StorageService tasks) async {
    final plans = await Hive.openBox<String>('plan_definitions_v1');
    final generated = await Hive.openBox<String>('plan_occurrences_v1');
    final service = PlanService._(plans, generated, tasks);
    await service.generateUpcoming();
    service._timer = Timer.periodic(
        const Duration(minutes: 1), (_) => service.generateUpcoming());
    return service;
  }

  List<PlanDefinition> get plans => _plans.values
      .map((value) => PlanDefinition.fromJson(
          Map<String, dynamic>.from(jsonDecode(value) as Map)))
      .toList();

  Future<void> save(PlanDefinition plan) async {
    final previousJson = _plans.get(plan.id);
    final previous = previousJson == null
        ? null
        : PlanDefinition.fromJson(
            Map<String, dynamic>.from(jsonDecode(previousJson) as Map));
    await _plans.put(plan.id, jsonEncode(plan.toJson()));
    notifyListeners();
    if (previous != null) await _refreshFutureTasks(previous, plan);
    await generateUpcoming();
  }

  // Keep one-off edits independent: update only instances still matching the
  // previous template, and leave completed/failed tasks and their IDs intact.
  Future<void> _refreshFutureTasks(
      PlanDefinition previous, PlanDefinition updated) async {
    final now = DateTime.now();
    final tasks = {for (final task in _tasks.getAllTasks()) task.id: task};
    for (final key in _generated.keys) {
      final parts = key.split(':');
      if (parts.length != 3 || parts[0] != updated.id) continue;
      final day = DateTime.tryParse(parts[2]);
      if (day == null) continue;
      final oldEntry =
          previous.entries.where((entry) => entry.id == parts[1]).firstOrNull;
      final newEntry =
          updated.entries.where((entry) => entry.id == parts[1]).firstOrNull;
      if (oldEntry == null || newEntry == null) continue;
      final parity = updated.isOddOn(day) ? 'odd' : 'even';
      if (newEntry.weekday != day.weekday ||
          (newEntry.weeks != 'both' && newEntry.weeks != parity)) {
        continue;
      }
      final task = tasks[_generated.get(key)];
      if (task == null ||
          task.status != TaskStatus.pending ||
          !task.startTime.isAfter(now)) {
        continue;
      }
      final baseline = oldEntry.taskOn(day, id: task.id);
      if (!_matchesTemplate(task, baseline)) continue;
      final replacement = newEntry.taskOn(day, id: task.id);
      await _tasks.updateTask(task.copyWith(
        title: replacement.title,
        description: replacement.description,
        category: replacement.category,
        isTimeBound: replacement.isTimeBound,
        targetDate: replacement.targetDate,
        startTime: replacement.startTime,
        endTime: replacement.endTime,
        reminderIntervalMinutes: replacement.reminderIntervalMinutes,
        customNotificationMessage: replacement.customNotificationMessage,
        clearCustomNotificationMessage:
            replacement.customNotificationMessage == null,
        notificationSoundId: replacement.notificationSoundId,
        customSystemSoundUri: replacement.customSystemSoundUri,
        clearCustomSystemSoundUri: replacement.customSystemSoundUri == null,
        notificationTimerOptions: replacement.notificationTimerOptions,
        isAlarm: replacement.isAlarm,
        alarmSoundType: replacement.alarmSoundType,
        alarmSoundId: replacement.alarmSoundId,
        alarmSoundUri: replacement.alarmSoundUri,
        clearAlarmSoundUri: replacement.alarmSoundUri == null,
      ));
    }
  }

  bool _matchesTemplate(Task actual, Task template) =>
      actual.title == template.title &&
      actual.description == template.description &&
      actual.category == template.category &&
      actual.isTimeBound == template.isTimeBound &&
      actual.targetDate == template.targetDate &&
      actual.startTime == template.startTime &&
      actual.endTime == template.endTime &&
      actual.reminderIntervalMinutes == template.reminderIntervalMinutes &&
      actual.customNotificationMessage == template.customNotificationMessage &&
      actual.notificationSoundId == template.notificationSoundId &&
      actual.customSystemSoundUri == template.customSystemSoundUri &&
      actual.notificationTimerOptions.length ==
          template.notificationTimerOptions.length &&
      actual.notificationTimerOptions
          .containsAll(template.notificationTimerOptions) &&
      actual.isAlarm == template.isAlarm &&
      actual.alarmSoundType == template.alarmSoundType &&
      actual.alarmSoundId == template.alarmSoundId &&
      actual.alarmSoundUri == template.alarmSoundUri;

  /// Removes the plan and all generated tasks through the task writer.
  Future<void> deletePlan(String id) async {
    await _plans.delete(id);
    notifyListeners();
    final keys =
        _generated.keys.where((key) => key.startsWith('$id:')).toList();
    final taskIds = _tasks.getAllTasks().map((task) => task.id).toSet();
    for (final key in keys) {
      final taskId = _generated.get(key);
      if (taskId != null && taskIds.remove(taskId)) {
        await _tasks.deleteTask(taskId);
      }
      await _generated.delete(key);
    }
  }

  Future<void> setCurrentWeek(PlanDefinition plan, bool odd) async {
    await save(plan.withCurrentWeek(odd, DateTime.now()));
  }

  /// Creates ordinary tasks for today and the next two weeks. A ledger avoids
  /// recreating an occurrence that the user later deletes or completes.
  Future<void> generateUpcoming({DateTime? clock}) async {
    if (_generating) return;
    _generating = true;
    try {
      final now = clock ?? DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final existing = {for (final task in _tasks.getAllTasks()) task.id: task};
      final existingIds = existing.keys.toSet();
      final definitions = plans;
      // Remove future pending instances that no longer match an edited week.
      for (final key in _generated.keys.toList()) {
        final parts = key.split(':');
        if (parts.length != 3) continue;
        final plan =
            definitions.where((item) => item.id == parts[0]).firstOrNull;
        if (plan == null) continue;
        final date = DateTime.tryParse(parts[2]);
        if (date == null) continue;
        final entry =
            plan.entries.where((item) => item.id == parts[1]).firstOrNull;
        final matches = entry != null &&
            entry.weekday == date.weekday &&
            (entry.weeks == 'both' ||
                entry.weeks == (plan.isOddOn(date) ? 'odd' : 'even'));
        if (matches) continue;
        final id = _generated.get(key);
        final task = existing[id];
        if (task != null &&
            task.status == TaskStatus.pending &&
            task.startTime.isAfter(now)) {
          await _tasks.deleteTask(task.id);
          existingIds.remove(task.id);
          await _generated.delete(key);
        }
      }
      for (final plan in definitions) {
        for (var offset = 0; offset < 15; offset++) {
          final day = DateTime(today.year, today.month, today.day + offset);
          final parity = plan.isOddOn(day) ? 'odd' : 'even';
          for (final entry in plan.entries) {
            if (entry.weekday != day.weekday ||
                (entry.weeks != 'both' && entry.weeks != parity)) {
              continue;
            }
            final occurrenceKey =
                '${plan.id}:${entry.id}:${day.year}-${day.month}-${day.day}';
            if (_generated.containsKey(occurrenceKey)) continue;
            final id = const Uuid()
                .v5('6ba7b811-9dad-11d1-80b4-00c04fd430c8', occurrenceKey);
            if (!existingIds.contains(id)) {
              await _tasks.addTask(entry.taskOn(day, id: id));
              existingIds.add(id);
            }
            await _generated.put(occurrenceKey, id);
          }
        }
      }
    } finally {
      _generating = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
