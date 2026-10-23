import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

/// Local Saturday-start calendar week, independent of UTC and daylight saving.
DateTime saturdayOf(DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  return DateTime(day.year, day.month, day.day - (day.weekday + 1) % 7);
}

String weeklyKey(DateTime date) {
  final saturday = saturdayOf(date);
  return '${saturday.year.toString().padLeft(4, '0')}-${saturday.month.toString().padLeft(2, '0')}-${saturday.day.toString().padLeft(2, '0')}';
}

class WeeklyResult {
  const WeeklyResult(this.done, this.target);
  final int done;
  final int target;

  Map<String, int> toJson() => {'done': done, 'target': target};
}

class WeeklyTask {
  WeeklyTask({
    String? id,
    required this.title,
    this.description = '',
    required this.targetPerWeek,
    this.doneThisWeek = 0,
    required this.weekKey,
    Map<String, WeeklyResult>? history,
  })  : id = id ?? const Uuid().v4(),
        history = history ?? {} {
    if (title.trim().isEmpty ||
        targetPerWeek < 1 ||
        doneThisWeek < 0 ||
        doneThisWeek > targetPerWeek) {
      throw ArgumentError('Invalid weekly task');
    }
  }

  final String id;
  final String title;
  final String description;
  final int targetPerWeek;
  final int doneThisWeek;
  final String weekKey;
  final Map<String, WeeklyResult> history;

  WeeklyResult resultFor(String key) => key == weekKey
      ? WeeklyResult(doneThisWeek, targetPerWeek)
      : history[key] ?? const WeeklyResult(0, 0);

  WeeklyTask copyWith(
          {String? title,
          String? description,
          int? targetPerWeek,
          int? doneThisWeek,
          String? weekKey,
          Map<String, WeeklyResult>? history}) =>
      WeeklyTask(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        targetPerWeek: targetPerWeek ?? this.targetPerWeek,
        doneThisWeek: doneThisWeek ?? this.doneThisWeek,
        weekKey: weekKey ?? this.weekKey,
        history: history ?? this.history,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'targetPerWeek': targetPerWeek,
        'doneThisWeek': doneThisWeek,
        'weekKey': weekKey,
        'history': history.map((key, value) => MapEntry(key, value.toJson())),
      };

  factory WeeklyTask.fromJson(Map<String, dynamic> json) {
    final rawHistory = json['history'] as Map<String, dynamic>? ?? {};
    return WeeklyTask(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      targetPerWeek: json['targetPerWeek'] as int,
      doneThisWeek: json['doneThisWeek'] as int? ?? 0,
      weekKey: json['weekKey'] as String,
      history: rawHistory.map((key, value) {
        final result = Map<String, dynamic>.from(value as Map);
        return MapEntry(
            key, WeeklyResult(result['done'] as int, result['target'] as int));
      }),
    );
  }
}

/// A separate String box avoids any changes to the existing Task adapters.
class WeeklyTaskService extends ChangeNotifier {
  WeeklyTaskService._(this._box) {
    _scheduleRollover();
  }

  final Box<String> _box;
  late Timer _timer;
  bool _disposed = false;

  void _scheduleRollover() {
    final now = DateTime.now();
    final start = saturdayOf(now);
    final next = DateTime(start.year, start.month, start.day + 7);
    _timer = Timer(next.difference(now), () async {
      await reconcileWeek();
      if (!_disposed) _scheduleRollover();
    });
  }

  static Future<WeeklyTaskService> initialize() async {
    final service =
        WeeklyTaskService._(await Hive.openBox<String>('weekly_tasks'));
    await service.reconcileWeek();
    return service;
  }

  List<WeeklyTask> getAll() => _box.values
      .map((value) =>
          WeeklyTask.fromJson(jsonDecode(value) as Map<String, dynamic>))
      .toList();

  Future<void> save(WeeklyTask task) async {
    await _box.put(task.id, jsonEncode(task.toJson()));
    notifyListeners();
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
    notifyListeners();
  }

  Future<void> adjust(String id, int delta) async {
    await reconcileWeek();
    final raw = _box.get(id);
    if (raw == null) return;
    final task = WeeklyTask.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    final count = (task.doneThisWeek + delta).clamp(0, task.targetPerWeek);
    if (count != task.doneThisWeek) {
      await save(task.copyWith(doneThisWeek: count));
    }
  }

  Future<void> reconcileWeek({DateTime? now}) async {
    final key = weeklyKey(now ?? DateTime.now());
    var changed = false;
    for (final task in getAll()) {
      if (task.weekKey == key) continue;
      final history = Map<String, WeeklyResult>.from(task.history);
      history[task.weekKey] =
          WeeklyResult(task.doneThisWeek, task.targetPerWeek);
      final previousWeek = DateTime.parse(task.weekKey);
      final currentWeek = DateTime.parse(key);
      for (var week = DateTime(
              previousWeek.year, previousWeek.month, previousWeek.day + 7);
          week.isBefore(currentWeek);
          week = DateTime(week.year, week.month, week.day + 7)) {
        history.putIfAbsent(
            weeklyKey(week), () => WeeklyResult(0, task.targetPerWeek));
      }
      await _box.put(
          task.id,
          jsonEncode(task
              .copyWith(
                weekKey: key,
                doneThisWeek: 0,
                history: history,
              )
              .toJson()));
      changed = true;
    }
    if (changed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer.cancel();
    super.dispose();
  }
}
