import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/task.dart';
import '../theme/app_theme.dart';

class TaskCard extends StatefulWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onDelete,
    required this.onEdit,
    required this.onExpire,
  });

  final Task task;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final Future<void> Function() onExpire;

  @override
  State<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard> {
  Timer? _timer;
  bool _failing = false;

  @override
  void initState() {
    super.initState();
    _syncTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) => _failIfExpired());
  }

  void _syncTimer() {
    final needsTimer =
        widget.task.isTimeBound && widget.task.status == TaskStatus.pending;
    if (!needsTimer) {
      _timer?.cancel();
      _timer = null;
    } else {
      _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {});
        _failIfExpired();
      });
    }
  }

  @override
  void didUpdateWidget(covariant TaskCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTimer();
    if (oldWidget.task.id != widget.task.id ||
        oldWidget.task.endTime != widget.task.endTime ||
        oldWidget.task.status != widget.task.status) {
      _failing = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _failIfExpired());
    }
  }

  Future<void> _failIfExpired() async {
    if (!mounted ||
        _failing ||
        !widget.task.isTimeBound ||
        widget.task.status != TaskStatus.pending ||
        !DateTime.now().isAfter(widget.task.endTime)) {
      return;
    }
    _failing = true;
    try {
      await widget.onExpire();
    } finally {
      _failing = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final failed = task.status == TaskStatus.failed;
    final complete = task.status == TaskStatus.completed;
    final accent = failed
        ? AppTheme.failed
        : complete
            ? AppTheme.completed
            : AppTheme.cyan;
    final now = DateTime.now();
    final active = task.status == TaskStatus.pending &&
        task.isTimeBound &&
        !now.isBefore(task.startTime) &&
        now.isBefore(task.endTime);
    final window = '${DateFormat.MMMd().format(task.targetDate)} · '
        '${DateFormat('HH:mm:ss').format(task.startTime)} – ${DateFormat('HH:mm:ss').format(task.endTime)}';
    final countdown = now.isBefore(task.startTime)
        ? 'Starts in ${_duration(task.startTime.difference(now))}'
        : now.isBefore(task.endTime)
            ? '${_duration(task.endTime.difference(now))} remaining'
            : 'Failed';
    final totalDuration = task.endTime.difference(task.startTime).inSeconds;
    final elapsedDuration = now.difference(task.startTime).inSeconds;
    final double progress = totalDuration > 0
        ? (elapsedDuration / totalDuration).clamp(0.0, 1.0)
        : 0.0;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.neonCard(accent: accent),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (failed)
            const Padding(
              padding: EdgeInsets.only(top: 9, right: 12),
              child: Icon(Icons.close_rounded, color: AppTheme.failed),
            )
          else
            Checkbox(
              value: complete,
              onChanged: (_) => widget.onToggle(),
              activeColor: AppTheme.completed,
              side: const BorderSide(color: AppTheme.cyan),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        decoration: failed ? TextDecoration.lineThrough : null,
                        color: failed ? Colors.white54 : null,
                      ),
                ),
                if (task.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    task.description,
                    style: TextStyle(
                      color: failed ? Colors.white38 : Colors.white70,
                    ),
                  ),
                ],
                const SizedBox(height: 9),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _badge(task.category.label, AppTheme.purple),
                    if (failed) _badge('FAILED', AppTheme.failed),
                    if (complete) _badge('DONE', AppTheme.completed),
                    if (task.isTimeBound) _badge(window, AppTheme.cyan),
                    if (task.isTimeBound && !failed && !complete)
                      _badge(
                          countdown,
                          now.isBefore(task.endTime)
                              ? AppTheme.blue
                              : AppTheme.failed),
                  ],
                ),
                if (active) ...[
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, constraints) => Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.cyan.withValues(alpha: .35),
                            blurRadius: 12,
                          )
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      alignment: Alignment.centerLeft,
                      child: AnimatedContainer(
                        key: const ValueKey('task-progress-fill'),
                        duration: const Duration(seconds: 1),
                        curve: Curves.linear,
                        width: constraints.maxWidth * progress,
                        height: 8,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                              colors: [AppTheme.cyan, AppTheme.purple]),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Column(
            children: [
              if (!complete)
                IconButton(
                  tooltip: failed ? 'Retry / Reschedule' : 'Edit task',
                  onPressed: widget.onEdit,
                  icon: Icon(
                      failed ? Icons.replay_rounded : Icons.edit_outlined,
                      color: failed ? AppTheme.purple : AppTheme.cyan),
                ),
              IconButton(
                tooltip: 'Delete task',
                onPressed: widget.onDelete,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          border: Border.all(color: color.withValues(alpha: .6)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text, style: TextStyle(color: color, fontSize: 11)),
      );

  String _duration(Duration duration) {
    final seconds = duration.inSeconds.clamp(0, 86400000);
    final hours = (seconds ~/ 3600).toString().padLeft(2, '0');
    final minutes = (seconds ~/ 60 % 60).toString().padLeft(2, '0');
    final remainingSeconds = (seconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$remainingSeconds';
  }
}
