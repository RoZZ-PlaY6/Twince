import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/task.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

/// Analytics / Reports screen showing weekly/monthly task completion analytics.
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

enum _AnalyticsViewMode { weekly, monthly }

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  _AnalyticsViewMode _mode = _AnalyticsViewMode.weekly;
  DateTime _selectedDate = DateTime.now();

  // Cache for computed data
  List<_DaySummary> _daySummaries = [];
  _AnalyticsMetrics _metrics = _AnalyticsMetrics.empty();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _recalculate();
  }

  @override
  void didUpdateWidget(covariant AnalyticsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _recalculate();
  }

  Future<void> _recalculate() async {
    setState(() => _isLoading = true);
    try {
      final storage = context.read<StorageService>();
      final tasks = storage.getAllTasks();

      final metrics = _computeMetrics(tasks);
      final summaries = _computeDaySummaries(tasks);

      if (mounted) {
        setState(() {
          _metrics = metrics;
          _daySummaries = summaries;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  _AnalyticsMetrics _computeMetrics(List<Task> tasks) {
    final (start, end) = _getDateRange(_mode, _selectedDate);

    final filtered = tasks.where((task) {
      final date = _normalizeDate(task.targetDate);
      return date.isAfter(start.subtract(const Duration(days: 1))) &&
             date.isBefore(end.add(const Duration(days: 1))) &&
             (task.status == TaskStatus.completed || task.status == TaskStatus.failed);
    }).toList();

    final completed = filtered.where((t) => t.status == TaskStatus.completed).length;
    final failed = filtered.where((t) => t.status == TaskStatus.failed).length;
    final total = completed + failed;
    final rate = total > 0 ? (completed / total * 100) : 0.0;

    return _AnalyticsMetrics(
      completed: completed,
      failed: failed,
      total: total,
      completionRate: rate,
    );
  }

  List<_DaySummary> _computeDaySummaries(List<Task> tasks) {
    final (start, end) = _getDateRange(_mode, _selectedDate);
    final days = <_DaySummary>[];

    for (var date = start; date.isBefore(end.add(const Duration(days: 1))); date = date.add(const Duration(days: 1))) {
      final dayTasks = tasks.where((task) =>
          _normalizeDate(task.targetDate).year == date.year &&
          _normalizeDate(task.targetDate).month == date.month &&
          _normalizeDate(task.targetDate).day == date.day &&
          (task.status == TaskStatus.completed || task.status == TaskStatus.failed)
      ).toList();

      final completed = dayTasks.where((t) => t.status == TaskStatus.completed).length;
      final failed = dayTasks.where((t) => t.status == TaskStatus.failed).length;

      if (completed > 0 || failed > 0) {
        days.add(_DaySummary(
          date: date,
          completed: completed,
          failed: failed,
          tasks: dayTasks,
        ));
      }
    }

    return days;
  }

  (DateTime, DateTime) _getDateRange(_AnalyticsViewMode mode, DateTime date) {
    if (mode == _AnalyticsViewMode.weekly) {
      // Monday as start of week
      final weekday = date.weekday; // 1 = Monday
      final start = date.subtract(Duration(days: weekday - 1));
      final end = start.add(const Duration(days: 6));
      return (DateTime(start.year, start.month, start.day), DateTime(end.year, end.month, end.day));
    } else {
      final start = DateTime(date.year, date.month, 1);
      final end = DateTime(date.year, date.month + 1, 0);
      return (start, end);
    }
  }

  DateTime _normalizeDate(DateTime date) => DateTime(date.year, date.month, date.day);

   Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _selectedDate;
    DateTime? picked;

    if (_mode == _AnalyticsViewMode.weekly) {
      picked = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(2000),
        lastDate: DateTime(now.year + 10),
        selectableDayPredicate: (day) => true,
      );
    } else {
      picked = await showDatePicker(
        context: context,
        initialDate: DateTime(initial.year, initial.month, 1),
        firstDate: DateTime(2000),
        lastDate: DateTime(now.year + 10, 12, 31),
        initialEntryMode: DatePickerEntryMode.calendarOnly,
      );
    }

    if (picked != null) {
      final nonNullDate = picked;
      setState(() => _selectedDate = nonNullDate);
    }
  }


  void _changeDate(int delta) {
    setState(() {
      if (_mode == _AnalyticsViewMode.weekly) {
        _selectedDate = _selectedDate.add(Duration(days: delta * 7));
      } else {
        final newMonth = _selectedDate.month + delta;
        final newYear = _selectedDate.year + (newMonth - 1) ~/ 12;
        final normalizedMonth = ((newMonth - 1) % 12) + 1;
        _selectedDate = DateTime(newYear, normalizedMonth, 1);
      }
    });
  }

  String _getRangeLabel() {
    final (start, end) = _getDateRange(_mode, _selectedDate);
    if (_mode == _AnalyticsViewMode.weekly) {
      return 'Week of ${DateFormat.MMMd().format(start)} - ${DateFormat.MMMd().format(end)}';
    } else {
      return DateFormat.yMMMM().format(_selectedDate);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Analytics'),
          actions: [
            IconButton(
              tooltip: 'Switch view',
              icon: Icon(_mode == _AnalyticsViewMode.weekly
                  ? Icons.calendar_month
                  : Icons.calendar_view_week),
              onPressed: () => setState(() =>
                  _mode = _mode == _AnalyticsViewMode.weekly
                      ? _AnalyticsViewMode.monthly
                      : _AnalyticsViewMode.weekly),
            ),
          ],
        ),
        body: Column(
          children: [
            // Header with controls
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                border: Border(bottom: BorderSide(color: AppTheme.purple.withOpacity(0.3))),
              ),
              child: Column(
                children: [
                  // View mode toggle
                  Row(
                    children: [
                      _ViewModeButton(
                        label: 'Weekly',
                        selected: _mode == _AnalyticsViewMode.weekly,
                        onTap: () => setState(() => _mode = _AnalyticsViewMode.weekly),
                      ),
                      const SizedBox(width: 8),
                      _ViewModeButton(
                        label: 'Monthly',
                        selected: _mode == _AnalyticsViewMode.monthly,
                        onTap: () => setState(() => _mode = _AnalyticsViewMode.monthly),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Date navigation
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Previous',
                        icon: const Icon(Icons.chevron_left, color: AppTheme.cyan),
                        onPressed: () => _changeDate(-1),
                      ),
                      Expanded(
                        child: Text(
                          _getRangeLabel(),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppTheme.cyan,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Next',
                        icon: const Icon(Icons.chevron_right, color: AppTheme.cyan),
                        onPressed: () => _changeDate(1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_month, color: AppTheme.cyan, size: 18),
                    label: const Text('Pick date'),
                    onPressed: _pickDate,
                  ),
                ],
              ),
            ),

            // Metrics cards
            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else ...[
              _MetricsRow(metrics: _metrics),
              const SizedBox(height: 16),

              // Day summaries / drill-down list
              Expanded(
                child: _daySummaries.isEmpty
                    ? Center(
                        child: Text(
                          _mode == _AnalyticsViewMode.weekly
                              ? 'No completed/failed tasks this week'
                              : 'No completed/failed tasks this month',
                          style: const TextStyle(color: Colors.white54),
                        ))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: _daySummaries.length,
                        itemBuilder: (context, index) =>
                            _DaySummaryTile(summary: _daySummaries[index]),
                      ),
              ),
            ],
          ],
        ),
      );
}

class _ViewModeButton extends StatelessWidget {
  const _ViewModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? AppTheme.cyan.withOpacity(0.2) : AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? AppTheme.cyan : AppTheme.purple.withOpacity(0.5),
              ),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? AppTheme.cyan : Colors.white70,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ),
      );
}

class _AnalyticsMetrics {
  const _AnalyticsMetrics({
    required this.completed,
    required this.failed,
    required this.total,
    required this.completionRate,
  });

  final int completed;
  final int failed;
  final int total;
  final double completionRate;

  factory _AnalyticsMetrics.empty() => const _AnalyticsMetrics(
        completed: 0,
        failed: 0,
        total: 0,
        completionRate: 0.0,
      );
}

class _MetricsRow extends StatelessWidget {
  const _MetricsRow({required this.metrics});

  final _AnalyticsMetrics metrics;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            _MetricCard(
              label: 'Completed',
              value: metrics.completed.toString(),
              color: AppTheme.completed,
              icon: Icons.check_circle_outline,
            ),
            const SizedBox(width: 8),
            _MetricCard(
              label: 'Failed',
              value: metrics.failed.toString(),
              color: AppTheme.failed,
              icon: Icons.cancel_outlined,
            ),
            const SizedBox(width: 8),
            _MetricCard(
              label: 'Rate',
              value: '${metrics.completionRate.toStringAsFixed(1)}%',
              color: AppTheme.cyan,
              icon: Icons.insights_outlined,
            ),
          ],
        ),
      );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                label,
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          ),
        ),
      );
}

class _DaySummary {
  const _DaySummary({
    required this.date,
    required this.completed,
    required this.failed,
    required this.tasks,
  });

  final DateTime date;
  final int completed;
  final int failed;
  final List<Task> tasks;

  int get total => completed + failed;
  double get rate => total > 0 ? (completed / total * 100) : 0.0;
}

class _DaySummaryTile extends StatefulWidget {
  const _DaySummaryTile({required this.summary});

  final _DaySummary summary;

  @override
  State<_DaySummaryTile> createState() => _DaySummaryTileState();
}

class _DaySummaryTileState extends State<_DaySummaryTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    final color = summary.completed > summary.failed ? AppTheme.completed : AppTheme.failed;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: AppTheme.neonCard(accent: color),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat.EEEE().format(summary.date),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          DateFormat.yMMMd().format(summary.date),
                          style: const TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${summary.completed} Done · ${summary.failed} Failed',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${summary.rate.toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white54,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1, color: Colors.white12),
            ...widget.summary.tasks.map((task) => _DayTaskTile(task: task)),
          ],
        ],
      ),
    );
  }
}

class _DayTaskTile extends StatelessWidget {
  const _DayTaskTile({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final isCompleted = task.status == TaskStatus.completed;
    final color = isCompleted ? AppTheme.completed : AppTheme.failed;
    final label = isCompleted ? 'Completed' : 'Failed';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    decoration: !isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (task.description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    task.description,
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 2,
                  children: [
                    _TagChip(
                      label: task.category.name,
                      color: AppTheme.purple,
                    ),
                    _TagChip(
                      label: label,
                      color: color,
                    ),
                    if (task.isTimeBound)
                      _TagChip(
                        label:
                            '${DateFormat('HH:mm').format(task.startTime)} - ${DateFormat('HH:mm').format(task.endTime)}',
                        color: AppTheme.cyan,
                      ),
                    if (task.completedAt != null)
                      _TagChip(
                        label: 'Done: ${DateFormat('HH:mm:ss').format(task.completedAt!)}',
                        color: AppTheme.completed,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
}
