import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/task.dart';
import 'storage_service.dart';
import 'week_cycle_service.dart';

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

  Map<String, Object?> toJson() => {
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
    this.anchorSaturday,
    required this.entries,
  });

  final String id;
  final String name;
  final bool university;

  /// Legacy field retained for plan_definitions_v1 compatibility.
  final DateTime anchorMonday;
  final DateTime? anchorSaturday;
  final bool anchorOdd;
  final List<PlanEntry> entries;

  bool isOddOn(DateTime date) {
    // Older plans only stored a Monday anchor. Its week began on the preceding
    // Saturday; new plans also persist that Saturday explicitly.
    final saturday = anchorSaturday ?? saturdayStartingWeek(anchorMonday);
    final weeks = elapsedSaturdayWeeks(saturday, date);
    return weeks.isEven ? anchorOdd : !anchorOdd;
  }

  PlanDefinition withCurrentWeek(bool odd, DateTime now) => PlanDefinition(
        id: id,
        name: name,
        university: university,
        anchorMonday: anchorMonday,
        anchorSaturday: saturdayStartingWeek(now),
        anchorOdd: odd,
        entries: entries,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'university': university,
        'anchorMonday': anchorMonday.toIso8601String(),
        'anchorSaturday': anchorSaturday?.toIso8601String(),
        'anchorOdd': anchorOdd,
        'entries': entries.map((entry) => entry.toJson()).toList(),
      };

  factory PlanDefinition.fromJson(Map<String, dynamic> json) => PlanDefinition(
        id: json['id'] as String,
        name: json['name'] as String,
        university: json['university'] as bool,
        anchorMonday: DateTime.parse(json['anchorMonday'] as String),
        anchorSaturday: json['anchorSaturday'] == null
            ? null
            : saturdayStartingWeek(
                DateTime.parse(json['anchorSaturday'] as String)),
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
  bool _generateAgain = false;
  DateTime? _queuedClock;
  final List<Completer<void>> _generationWaiters = [];
  WeekCycleService? _cycle;

  static Future<PlanService> initialize(StorageService tasks,
      {WeekCycleService? cycle, DateTime? clock}) async {
    final plans = await Hive.openBox<String>('plan_definitions_v1');
    final generated = await Hive.openBox<String>('plan_occurrences_v1');
    final service = PlanService._(plans, generated, tasks);
    if (cycle != null) service.bindWeekCycle(cycle);
    await service.generateUpcoming(clock: clock);
    service._timer = Timer.periodic(
        const Duration(minutes: 1), (_) => service.generateUpcoming());
    return service;
  }

  void bindWeekCycle(WeekCycleService cycle) {
    if (identical(_cycle, cycle)) return;
    _cycle?.removeListener(_onWeekCycleChanged);
    _cycle = cycle;
    cycle.addListener(_onWeekCycleChanged);
  }

  void _onWeekCycleChanged() {
    notifyListeners();
    unawaited(generateUpcoming());
  }

  bool _weekIsOdd(PlanDefinition plan, DateTime day) {
    final cycle = _cycle;
    if (cycle != null && cycle.isConfigured) return cycle.isOddOn(day);
    return plan.isOddOn(day);
  }

  bool _entryRuns(PlanDefinition plan, PlanEntry entry, DateTime day) =>
      planEntryRunsThisWeek(
        everyWeek: !plan.university,
        weeks: entry.weeks,
        oddWeek: _weekIsOdd(plan, day),
      );

  List<PlanDefinition> get plans => _plans.values
      .map((value) => PlanDefinition.fromJson(
          Map<String, dynamic>.from(jsonDecode(value) as Map)))
      .toList();

  Map<String, String> get occurrences => {
        for (final key in _generated.keys)
          if (_generated.get(key) != null) key: _generated.get(key)!,
      };

  /// Replaces every plan template and occurrence ledger entry.
  Future<void> replaceAll(
    List<PlanDefinition> definitions, {
    Map<String, String> occurrences = const {},
  }) async {
    await _plans.clear();
    await _generated.clear();
    for (final plan in definitions) {
      await _plans.put(plan.id, jsonEncode(plan.toJson()));
    }
    for (final entry in occurrences.entries) {
      await _generated.put(entry.key, entry.value);
    }
    notifyListeners();
    await generateUpcoming();
  }

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
      final day = _parsePlanDay(parts[2]);
      if (day == null) continue;
      final oldEntry =
          previous.entries.where((entry) => entry.id == parts[1]).firstOrNull;
      final newEntry =
          updated.entries.where((entry) => entry.id == parts[1]).firstOrNull;
      if (oldEntry == null || newEntry == null) continue;
      if (newEntry.weekday != day.weekday ||
          !_entryRuns(updated, newEntry, day)) {
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
    if (_cycle != null) {
      await _cycle!.chooseCurrentWeek(odd);
    } else {
      await save(plan.withCurrentWeek(odd, DateTime.now()));
    }
  }

  /// Creates ordinary tasks for today and the next two weeks. A ledger avoids
  /// recreating an occurrence that the user later deletes or completes.
  Future<void> generateUpcoming({DateTime? clock}) async {
    if (_generating) {
      _generateAgain = true;
      if (clock != null) _queuedClock = clock;
      final waiter = Completer<void>();
      _generationWaiters.add(waiter);
      await waiter.future;
      return;
    }
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
        final date = _parsePlanDay(parts[2]);
        if (date == null) continue;
        final entry =
            plan.entries.where((item) => item.id == parts[1]).firstOrNull;
        final matches = entry != null &&
            entry.weekday == date.weekday &&
            _entryRuns(plan, entry, date);
        if (matches) continue;
        final id = _generated.get(key);
        final task = existing[id];
        // Pending work whose alarm or window is still ahead must leave with
        // the week that no longer applies. deleteTask cancels its alarm.
        if (task != null &&
            task.status == TaskStatus.pending &&
            task.endTime.isAfter(now)) {
          await _tasks.deleteTask(task.id);
          existingIds.remove(task.id);
          await _generated.delete(key);
        }
      }
      for (final plan in definitions) {
        for (var offset = 0; offset < 15; offset++) {
          final day = DateTime(today.year, today.month, today.day + offset);
          for (final entry in plan.entries) {
            if (entry.weekday != day.weekday || !_entryRuns(plan, entry, day)) {
              continue;
            }
            final occurrenceKey = _occurrenceKey(plan.id, entry.id, day);
            final legacyKey = _legacyOccurrenceKey(plan.id, entry.id, day);
            if (legacyKey != null && _generated.containsKey(legacyKey)) {
              final legacyId = _generated.get(legacyKey);
              if (legacyId != null) {
                await _generated.put(occurrenceKey, legacyId);
              }
              await _generated.delete(legacyKey);
            }
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
      if (_generateAgain) {
        final nextClock = _queuedClock;
        _generateAgain = false;
        _queuedClock = null;
        await generateUpcoming(clock: nextClock);
      }
      final waiters = List<Completer<void>>.of(_generationWaiters);
      _generationWaiters.clear();
      for (final waiter in waiters) {
        if (!waiter.isCompleted) waiter.complete();
      }
    }
  }

  String _occurrenceKey(String planId, String entryId, DateTime day) =>
      '$planId:$entryId:${_formatPlanDay(day)}';

  String? _legacyOccurrenceKey(String planId, String entryId, DateTime day) {
    final legacy = '$planId:$entryId:${day.year}-${day.month}-${day.day}';
    final current = _occurrenceKey(planId, entryId, day);
    return legacy == current ? null : legacy;
  }

  String _formatPlanDay(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  DateTime? _parsePlanDay(String value) {
    final parts = value.split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return date;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cycle?.removeListener(_onWeekCycleChanged);
    super.dispose();
  }
}
