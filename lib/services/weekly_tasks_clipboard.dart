import 'package:flutter/services.dart';

import 'weekly_task_service.dart';

/// The heading is the category name, or `All` when every weekly task is copied.
String formatWeeklyTasks(Iterable<WeeklyTask> tasks,
    {required String heading}) {
  final lines = tasks.map((task) =>
      '${task.title.replaceAll(RegExp(r'[\r\n]+'), ' ').trim()}: ${task.doneThisWeek} / ${task.targetPerWeek}');
  return [heading.trim(), ...lines].join('\n');
}

Future<void> copyWeeklyTasks(List<WeeklyTask> tasks,
        {required String heading}) =>
    Clipboard.setData(
        ClipboardData(text: formatWeeklyTasks(tasks, heading: heading)));
