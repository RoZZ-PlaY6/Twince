import 'package:flutter/services.dart';

import 'weekly_task_service.dart';

/// One line per weekly goal, using its current week's progress.
String formatWeeklyTasks(Iterable<WeeklyTask> tasks) => tasks
    .map((task) =>
        '${task.title.replaceAll(RegExp(r'[\r\n]+'), ' ').trim()}: ${task.doneThisWeek} / ${task.targetPerWeek}')
    .join('\n');

Future<void> copyWeeklyTasks(List<WeeklyTask> tasks) =>
    Clipboard.setData(ClipboardData(text: formatWeeklyTasks(tasks)));
