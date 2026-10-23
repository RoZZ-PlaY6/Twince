import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/task.dart';
import '../services/storage_service.dart';
import '../services/weekly_task_service.dart';
import '../theme/app_theme.dart';

enum _RangeMode { weekly, monthly, custom }

enum _ChartMode { bars, donut, distribution }

enum AnalyticsTaskType { all, standard, repeated }

/// A generated occurrence belongs to a series only through its definition id.
@visibleForTesting
bool isRepeatedOccurrence(Task task) => task.recurringDefinitionId != null;

/// Occurrences are stored tasks. A recurring definition is not an occurrence.
@visibleForTesting
List<Task> filterAnalyticsTasks(
  List<Task> tasks, {
  required DateTime rangeStart,
  required DateTime rangeEnd,
  required AnalyticsTaskType type,
}) {
  DateTime day(DateTime date) => DateTime(date.year, date.month, date.day);
  final start = day(rangeStart);
  final end = day(rangeEnd);
  final seen = <String>{};
  final inRange = <Task>[];
  for (final task in tasks) {
    if (!seen.add(task.id)) continue;
    final taskDay = day(task.targetDate);
    if (taskDay.isBefore(start) || taskDay.isAfter(end)) continue;
    final repeated = isRepeatedOccurrence(task);
    final include = switch (type) {
      AnalyticsTaskType.all => true,
      AnalyticsTaskType.standard => !repeated,
      AnalyticsTaskType.repeated => repeated,
    };
    if (include) inRange.add(task);
  }
  return inRange;
}

@visibleForTesting
double analyticsCompletionRate(List<Task> tasks) {
  if (tasks.isEmpty) return 0;
  final completed =
      tasks.where((task) => task.status == TaskStatus.completed).length;
  return completed * 100 / tasks.length;
}

/// One standard task, or one recurring series collapsed from its occurrences.
sealed class AnalyticsListItem {}

class AnalyticsStandardItem extends AnalyticsListItem {
  AnalyticsStandardItem(this.task);
  final Task task;
}

class AnalyticsSeriesItem extends AnalyticsListItem {
  AnalyticsSeriesItem({
    required this.definitionId,
    required this.title,
    required this.weekdays,
    required this.occurrences,
  });

  final String definitionId;
  final String title;
  final List<int> weekdays;
  final List<Task> occurrences;

  int get completedCount =>
      occurrences.where((task) => task.status == TaskStatus.completed).length;

  String get completionLabel =>
      '$completedCount/${occurrences.length} completed';
}

@visibleForTesting
String analyticsWeekdayLabel(List<int> weekdays) {
  const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return [
    for (final day in weekdays)
      if (day >= 1 && day <= 7) names[day - 1]
  ].join(' · ');
}

/// Groups already date-filtered occurrences. The series definition is not a row.
@visibleForTesting
List<AnalyticsListItem> groupAnalyticsList(
  List<Task> occurrences, {
  Map<String, List<int>> scheduledWeekdays = const {},
  Map<String, String> seriesTitles = const {},
}) {
  final bySeries = <String, List<Task>>{};
  for (final task in occurrences) {
    final id = task.recurringDefinitionId;
    if (!isRepeatedOccurrence(task) || id == null) continue;
    bySeries.putIfAbsent(id, () => []).add(task);
  }
  final seen = <String>{};
  final items = <AnalyticsListItem>[];
  for (final task in occurrences) {
    final id = task.recurringDefinitionId;
    if (!isRepeatedOccurrence(task) || id == null) {
      items.add(AnalyticsStandardItem(task));
      continue;
    }
    if (!seen.add(id)) continue;
    final series = [...bySeries[id]!]
      ..sort((a, b) => a.targetDate.compareTo(b.targetDate));
    final weekdays = List<int>.from(scheduledWeekdays[id] ??
        (series.map((item) => item.targetDate.weekday).toSet().toList()
          ..sort()));
    items.add(AnalyticsSeriesItem(
      definitionId: id,
      title: seriesTitles[id] ?? series.first.title,
      weekdays: weekdays,
      occurrences: series,
    ));
  }
  return items;
}

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key, this.embedded = false});
  final bool embedded;

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  _RangeMode _rangeMode = _RangeMode.weekly;
  _ChartMode _chartMode = _ChartMode.bars;
  AnalyticsTaskType _taskType = AnalyticsTaskType.all;
  final Set<String> _expandedSeries = {};
  bool _weeklyTasks = false;
  DateTime _selectedDate = DateTime.now();
  DateTimeRange? _customRange;

  DateTime _day(DateTime date) => DateTime(date.year, date.month, date.day);

  DateTimeRange get _range {
    if (_rangeMode == _RangeMode.custom) {
      return _customRange ??
          DateTimeRange(start: _day(_selectedDate), end: _day(_selectedDate));
    }
    if (_rangeMode == _RangeMode.weekly) {
      final start = _day(
          _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1)));
      return DateTimeRange(
          start: start, end: DateTime(start.year, start.month, start.day + 6));
    }
    return DateTimeRange(
      start: DateTime(_selectedDate.year, _selectedDate.month),
      end: DateTime(_selectedDate.year, _selectedDate.month + 1, 0),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    if (_rangeMode == _RangeMode.custom) {
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: DateTime(now.year + 10, 12, 31),
        initialDateRange: _customRange,
      );
      if (picked != null && mounted) setState(() => _customRange = picked);
      return;
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 10, 12, 31),
    );
    if (picked != null && mounted) setState(() => _selectedDate = picked);
  }

  void _move(int step) {
    if (_rangeMode == _RangeMode.custom) return;
    setState(() {
      if (_rangeMode == _RangeMode.weekly) {
        _selectedDate = DateTime(_selectedDate.year, _selectedDate.month,
            _selectedDate.day + step * 7);
      } else {
        _selectedDate =
            DateTime(_selectedDate.year, _selectedDate.month + step, 1);
      }
    });
  }

  String get _rangeLabel {
    final range = _range;
    if (_rangeMode == _RangeMode.monthly) {
      return DateFormat.yMMMM().format(_selectedDate);
    }
    return '${DateFormat.yMMMd().format(range.start)} – ${DateFormat.yMMMd().format(range.end)}';
  }

  @override
  Widget build(BuildContext context) {
    final range = _range;
    final storage = context.watch<StorageService>();
    final tasks = filterAnalyticsTasks(
      storage.getAllTasks(),
      rangeStart: range.start,
      rangeEnd: range.end,
      type: _taskType,
    );
    final definitions = storage.getRecurringTasks();
    final items = groupAnalyticsList(
      tasks,
      scheduledWeekdays: {
        for (final definition in definitions)
          definition.id: definition.weekdays,
      },
      seriesTitles: {
        for (final definition in definitions) definition.id: definition.title,
      },
    );

    return Scaffold(
      appBar: widget.embedded ? null : AppBar(title: const Text('Analytics')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _glass(
              child: Row(children: [
            Expanded(
                child: _choice('Tasks', !_weeklyTasks,
                    () => setState(() => _weeklyTasks = false),
                    icon: Icons.task_alt_outlined)),
            const SizedBox(width: 8),
            Expanded(
                child: _choice('Weekly tasks', _weeklyTasks,
                    () => setState(() => _weeklyTasks = true),
                    icon: Icons.date_range_outlined)),
          ])),
          const SizedBox(height: 12),
          _glass(
              child: Column(children: [
            Wrap(spacing: 8, runSpacing: 8, children: [
              _choice('Weekly', _rangeMode == _RangeMode.weekly,
                  () => setState(() => _rangeMode = _RangeMode.weekly)),
              _choice('Monthly', _rangeMode == _RangeMode.monthly,
                  () => setState(() => _rangeMode = _RangeMode.monthly)),
              _choice('Custom Date', _rangeMode == _RangeMode.custom, () {
                setState(() => _rangeMode = _RangeMode.custom);
                _pickDate();
              }),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              if (_rangeMode != _RangeMode.custom)
                IconButton(
                    tooltip: 'Previous',
                    onPressed: () => _move(-1),
                    icon: const Icon(Icons.chevron_left, color: AppTheme.cyan)),
              Expanded(
                  child: Text(_rangeLabel,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: const TextStyle(
                          color: AppTheme.cyan, fontWeight: FontWeight.w600))),
              if (_rangeMode != _RangeMode.custom)
                IconButton(
                    tooltip: 'Next',
                    onPressed: () => _move(1),
                    icon:
                        const Icon(Icons.chevron_right, color: AppTheme.cyan)),
            ]),
            TextButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(_rangeMode == _RangeMode.custom
                    ? 'Choose date range'
                    : 'Pick date')),
          ])),
          const SizedBox(height: 16),
          if (_weeklyTasks)
            ..._weeklyAnalytics(context, range)
          else ...[
            _metrics(tasks),
            const SizedBox(height: 20),
            const Text('Chart visualization',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _choice('نمودار ستونی / میله‌ای', _chartMode == _ChartMode.bars,
                  () => setState(() => _chartMode = _ChartMode.bars),
                  icon: Icons.bar_chart_rounded),
              _choice('نمودار دایره‌ای', _chartMode == _ChartMode.donut,
                  () => setState(() => _chartMode = _ChartMode.donut),
                  icon: Icons.donut_large_rounded),
              _choice(
                  'نمودار درصدی تفکیکی',
                  _chartMode == _ChartMode.distribution,
                  () => setState(() => _chartMode = _ChartMode.distribution),
                  icon: Icons.stacked_bar_chart_rounded),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: _choice('All', _taskType == AnalyticsTaskType.all,
                      () => setState(() => _taskType = AnalyticsTaskType.all))),
              const SizedBox(width: 8),
              Expanded(
                  child: _choice(
                      'Standard',
                      _taskType == AnalyticsTaskType.standard,
                      () => setState(
                          () => _taskType = AnalyticsTaskType.standard))),
              const SizedBox(width: 8),
              Expanded(
                  child: _choice(
                      'Repeated',
                      _taskType == AnalyticsTaskType.repeated,
                      () => setState(
                          () => _taskType = AnalyticsTaskType.repeated))),
            ]),
            const SizedBox(height: 20),
            ..._taskSection(tasks, items),
            _chartPanel(
                tasks,
                range,
                switch (_taskType) {
                  AnalyticsTaskType.all => 'Task performance',
                  AnalyticsTaskType.standard => 'Standard task performance',
                  AnalyticsTaskType.repeated => 'Repeated task performance',
                }),
          ],
        ],
      ),
    );
  }

  List<Widget> _weeklyAnalytics(BuildContext context, DateTimeRange range) {
    final tasks = context.watch<WeeklyTaskService>().getAll();
    final first = saturdayOf(range.start);
    final last = saturdayOf(range.end);
    final keys = <String>[];
    for (var week = first;
        !week.isAfter(last);
        week = DateTime(week.year, week.month, week.day + 7)) {
      keys.add(weeklyKey(week));
    }
    final results = <WeeklyTask, List<WeeklyResult>>{
      for (final task in tasks)
        task: [for (final key in keys) task.resultFor(key)]
            .where((result) => result.target > 0)
            .toList(),
    };
    final totalDone =
        results.values.expand((r) => r).fold<int>(0, (sum, r) => sum + r.done);
    final totalTarget = results.values
        .expand((r) => r)
        .fold<int>(0, (sum, r) => sum + r.target);
    final percentage = totalTarget == 0 ? 0.0 : totalDone * 100 / totalTarget;
    return [
      _glass(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Overall weekly goal completion',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text('${percentage.toStringAsFixed(1)}% · $totalDone / $totalTarget',
            style: const TextStyle(
                color: AppTheme.cyan,
                fontSize: 22,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: totalTarget == 0 ? 0 : totalDone / totalTarget,
              minHeight: 12,
              backgroundColor: AppTheme.background,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.purple),
            )),
      ])),
      const SizedBox(height: 16),
      Wrap(spacing: 8, runSpacing: 8, children: [
        _choice('Bar', _chartMode == _ChartMode.bars,
            () => setState(() => _chartMode = _ChartMode.bars),
            icon: Icons.bar_chart_rounded),
        _choice('Percentage', _chartMode == _ChartMode.distribution,
            () => setState(() => _chartMode = _ChartMode.distribution),
            icon: Icons.stacked_bar_chart_rounded),
      ]),
      const SizedBox(height: 16),
      if (tasks.isEmpty)
        _glass(
            child: const Text('No weekly tasks yet',
                style: TextStyle(color: Colors.white60))),
      for (final entry in results.entries)
        Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _weeklyChart(entry.key, entry.value, keys)),
    ];
  }

  Widget _weeklyChart(
      WeeklyTask task, List<WeeklyResult> results, List<String> keys) {
    final done = results.fold<int>(0, (sum, result) => sum + result.done);
    final target = results.fold<int>(0, (sum, result) => sum + result.target);
    return _glass(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(task.title, style: const TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      Text('$done / $target across ${results.length} recorded weeks',
          style: const TextStyle(color: Colors.white60, fontSize: 12)),
      const SizedBox(height: 12),
      if (results.isEmpty)
        const Text('No recorded weeks in this range',
            style: TextStyle(color: Colors.white54))
      else if (_chartMode == _ChartMode.bars)
        SizedBox(
            height: 115,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final key in keys)
                  if (task.resultFor(key).target > 0)
                    SizedBox(
                        width: 65,
                        child: Column(children: [
                          Expanded(
                              child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: Container(
                                    width: 26,
                                    height: 75 *
                                        task.resultFor(key).done /
                                        task.resultFor(key).target,
                                    decoration: BoxDecoration(
                                        color: AppTheme.cyan,
                                        borderRadius: BorderRadius.circular(5)),
                                  ))),
                          const SizedBox(height: 5),
                          Text(key.substring(5),
                              style: const TextStyle(
                                  color: Colors.white60, fontSize: 11)),
                        ])),
              ],
            ))
      else ...[
        ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: target == 0 ? 0 : done / target,
              minHeight: 16,
              backgroundColor: AppTheme.background,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.cyan),
            )),
        const SizedBox(height: 6),
        Text('${(target == 0 ? 0 : done * 100 / target).toStringAsFixed(1)}%',
            style: const TextStyle(color: AppTheme.cyan)),
      ],
    ]));
  }

  Widget _choice(String label, bool selected, VoidCallback onTap,
          {IconData? icon}) =>
      OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(
            icon ??
                (selected
                    ? Icons.check_circle_outline
                    : Icons.calendar_today_outlined),
            size: 17),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        style: OutlinedButton.styleFrom(
          foregroundColor: selected ? AppTheme.cyan : Colors.white70,
          backgroundColor: selected
              ? AppTheme.cyan.withAlpha(36)
              : AppTheme.surface.withAlpha(128),
          side: BorderSide(
              color: selected ? AppTheme.cyan : AppTheme.purple.withAlpha(102)),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        ),
      );

  Widget _glass({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface.withAlpha(184),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.purple.withAlpha(107)),
          boxShadow: [
            BoxShadow(color: AppTheme.cyan.withAlpha(14), blurRadius: 18)
          ],
        ),
        child: child,
      );

  Widget _sectionTitle(String title, int count) => Row(children: [
        Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700))),
        Text('$count', style: const TextStyle(color: AppTheme.cyan)),
      ]);

  Widget _metrics(List<Task> tasks) {
    final counts = _counts(tasks);
    return _glass(
        child: Wrap(
            spacing: 18,
            runSpacing: 12,
            alignment: WrapAlignment.spaceEvenly,
            children: [
          _stat('Completed', counts[0], AppTheme.completed),
          _stat('Pending', counts[1], AppTheme.cyan),
          _stat('Failed', counts[2], AppTheme.failed),
          _stat(
              'Rate', '${_rate(counts).toStringAsFixed(1)}%', AppTheme.purple),
        ]));
  }

  Widget _stat(String name, Object value, Color color) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        Text('$value',
            style: TextStyle(
                color: color, fontSize: 21, fontWeight: FontWeight.bold)),
        Text(name, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ]);

  List<Widget> _taskSection(List<Task> tasks, List<AnalyticsListItem> items) {
    final title = switch (_taskType) {
      AnalyticsTaskType.all => 'Tasks',
      AnalyticsTaskType.standard => 'Standard tasks',
      AnalyticsTaskType.repeated => 'Repeated tasks',
    };
    final empty = switch (_taskType) {
      AnalyticsTaskType.all => 'No tasks in this range',
      AnalyticsTaskType.standard => 'No standard tasks in this range',
      AnalyticsTaskType.repeated => 'No repeated tasks in this range',
    };
    return [
      _sectionTitle(title, tasks.length),
      const SizedBox(height: 8),
      if (items.isEmpty)
        _glass(
            child: Text(empty, style: const TextStyle(color: Colors.white60)))
      else
        for (final item in items)
          if (item is AnalyticsSeriesItem)
            _seriesRow(item)
          else if (item is AnalyticsStandardItem)
            _taskRow(item.task),
      const SizedBox(height: 10),
    ];
  }

  Widget _seriesRow(AnalyticsSeriesItem series) {
    final expanded = _expandedSeries.contains(series.definitionId);
    final weekdays = analyticsWeekdayLabel(series.weekdays);
    return Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: _glass(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          InkWell(
              key: ValueKey('analytics-series-${series.definitionId}'),
              onTap: () => setState(() {
                    if (!_expandedSeries.add(series.definitionId)) {
                      _expandedSeries.remove(series.definitionId);
                    }
                  }),
              child: Row(children: [
                const Icon(Icons.repeat_rounded, color: AppTheme.cyan),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(series.title,
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(
                          [
                            if (weekdays.isNotEmpty) weekdays,
                            series.completionLabel,
                          ].join('  ·  '),
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                    ])),
                Icon(expanded ? Icons.expand_less : Icons.expand_more,
                    color: AppTheme.cyan),
              ])),
          if (expanded)
            for (final occurrence in series.occurrences)
              Padding(
                  padding: const EdgeInsets.only(top: 10, left: 4),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(occurrence.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(DateFormat.yMMMd().format(occurrence.targetDate),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 6),
                        Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _analyticsBadge(
                                  occurrence.category.label, AppTheme.purple),
                              if (occurrence.isTimeBound)
                                _analyticsBadge(
                                    '${DateFormat('HH:mm').format(occurrence.startTime)} – ${DateFormat('HH:mm').format(occurrence.endTime)}',
                                    AppTheme.cyan),
                              Text(occurrence.status.name,
                                  style: TextStyle(
                                      color: _statusColor(occurrence.status),
                                      fontSize: 12)),
                            ]),
                      ])),
        ])));
  }

  Widget _analyticsBadge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          border: Border.all(color: color.withValues(alpha: 0.58)),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 8),
          ],
        ),
        child: Text(text,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      );

  Widget _taskRow(Task task) {
    final color = _statusColor(task.status);
    return Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: _glass(
            child: Row(children: [
          Icon(
              task.status == TaskStatus.completed
                  ? Icons.check_circle_outline
                  : task.status == TaskStatus.failed
                      ? Icons.cancel_outlined
                      : Icons.schedule_outlined,
              color: color),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(task.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                Text(DateFormat.yMMMd().format(task.targetDate),
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 12)),
              ])),
          const SizedBox(width: 8),
          Text(task.status.name, style: TextStyle(color: color, fontSize: 12)),
        ])));
  }

  List<int> _counts(List<Task> tasks) => [
        tasks.where((t) => t.status == TaskStatus.completed).length,
        tasks.where((t) => t.status == TaskStatus.pending).length,
        tasks.where((t) => t.status == TaskStatus.failed).length,
      ];

  double _rate(List<int> counts) => counts.reduce((a, b) => a + b) == 0
      ? 0
      : counts[0] * 100 / counts.reduce((a, b) => a + b);

  Color _statusColor(TaskStatus status) => switch (status) {
        TaskStatus.completed => AppTheme.completed,
        TaskStatus.pending => AppTheme.cyan,
        TaskStatus.failed => AppTheme.failed,
      };

  Widget _chartPanel(List<Task> tasks, DateTimeRange range, String title) {
    final counts = _counts(tasks);
    return _glass(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Text(
          '${tasks.length} occurrences · ${_rate(counts).toStringAsFixed(1)}% completed',
          style: const TextStyle(color: Colors.white60, fontSize: 12)),
      const SizedBox(height: 16),
      if (tasks.isEmpty)
        const Center(
            child: Padding(
                padding: EdgeInsets.all(18),
                child: Text('No data in this range',
                    style: TextStyle(color: Colors.white54))))
      else if (_chartMode == _ChartMode.bars)
        _bars(tasks, range)
      else if (_chartMode == _ChartMode.donut)
        _donut(counts)
      else
        _distribution(counts),
      if (tasks.isNotEmpty) ...[
        const SizedBox(height: 14),
        Wrap(spacing: 16, runSpacing: 6, children: [
          _legend('Completed', counts[0], AppTheme.completed),
          _legend('Pending', counts[1], AppTheme.cyan),
          _legend('Failed', counts[2], AppTheme.failed),
        ]),
      ],
    ]));
  }

  Widget _legend(String label, int count, Color color) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text('$label $count',
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ]);

  Widget _bars(List<Task> tasks, DateTimeRange range) {
    final days = DateTime.utc(range.end.year, range.end.month, range.end.day)
            .difference(DateTime.utc(
                range.start.year, range.start.month, range.start.day))
            .inDays +
        1;
    final byDay = <DateTime, List<int>>{};
    for (final task in tasks) {
      final counts = byDay.putIfAbsent(_day(task.targetDate), () => [0, 0, 0]);
      counts[task.status == TaskStatus.completed
          ? 0
          : task.status == TaskStatus.pending
              ? 1
              : 2]++;
    }
    final buckets = List.generate(days, (i) {
      final day =
          DateTime(range.start.year, range.start.month, range.start.day + i);
      return byDay[day] ?? [0, 0, 0];
    });
    final maxCount = math.max(
        1, buckets.map((b) => b.reduce((a, b) => a + b)).reduce(math.max));
    return SizedBox(
        height: 174,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: days,
          itemBuilder: (context, i) => SizedBox(
              width: 47,
              child: Column(children: [
                Expanded(
                    child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Tooltip(
                          message:
                              '${DateFormat.yMMMd().format(DateTime(range.start.year, range.start.month, range.start.day + i))}: ${buckets[i][0]} completed, ${buckets[i][1]} pending, ${buckets[i][2]} failed',
                          child: SizedBox(
                              width: 25,
                              height: 130,
                              child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    for (final index in [2, 1, 0])
                                      if (buckets[i][index] > 0)
                                        Container(
                                            height: 120 *
                                                buckets[i][index] /
                                                maxCount,
                                            decoration: BoxDecoration(
                                              color: [
                                                AppTheme.completed,
                                                AppTheme.cyan,
                                                AppTheme.failed
                                              ][index],
                                              borderRadius:
                                                  BorderRadius.circular(3),
                                            )),
                                  ])),
                        ))),
                const SizedBox(height: 6),
                Text(
                    DateFormat('d/M').format(DateTime(range.start.year,
                        range.start.month, range.start.day + i)),
                    style:
                        const TextStyle(color: Colors.white60, fontSize: 10)),
              ])),
        ));
  }

  Widget _donut(List<int> counts) => Center(
      child: SizedBox(
          width: 180,
          height: 180,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                  size: const Size(180, 180), painter: _DonutPainter(counts)),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text('${_rate(counts).toStringAsFixed(0)}%',
                    style: const TextStyle(
                        color: AppTheme.cyan,
                        fontSize: 27,
                        fontWeight: FontWeight.bold)),
                const Text('completed',
                    style: TextStyle(color: Colors.white60, fontSize: 12)),
              ]),
            ],
          )));

  Widget _distribution(List<int> counts) {
    final total = counts.reduce((a, b) => a + b);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: SizedBox(
              height: 22,
              child: Row(children: [
                for (var i = 0; i < 3; i++)
                  if (counts[i] > 0)
                    Expanded(
                        flex: counts[i],
                        child: ColoredBox(
                            color: [
                              AppTheme.completed,
                              AppTheme.cyan,
                              AppTheme.failed
                            ][i],
                            child: const SizedBox.expand())),
              ]))),
      const SizedBox(height: 12),
      for (var i = 0; i < 3; i++)
        Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(children: [
              Expanded(
                  child: Text(['Completed', 'Pending', 'Failed'][i],
                      style: const TextStyle(color: Colors.white70))),
              Text('${(counts[i] * 100 / total).toStringAsFixed(1)}%',
                  style: TextStyle(
                      color: [
                    AppTheme.completed,
                    AppTheme.cyan,
                    AppTheme.failed
                  ][i])),
            ])),
    ]);
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter(this.counts);
  final List<int> counts;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(10, 10, size.width - 20, size.height - 20);
    var angle = -math.pi / 2;
    final total = counts.reduce((a, b) => a + b);
    for (var i = 0; i < counts.length; i++) {
      if (counts[i] == 0) continue;
      final sweep = counts[i] * 2 * math.pi / total;
      canvas.drawArc(
          rect,
          angle,
          sweep,
          false,
          Paint()
            ..color = [AppTheme.completed, AppTheme.cyan, AppTheme.failed][i]
            ..style = PaintingStyle.stroke
            ..strokeWidth = 22
            ..strokeCap = StrokeCap.butt);
      angle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      !listEquals(counts, oldDelegate.counts);
}
