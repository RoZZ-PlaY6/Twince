import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/weekly_task_service.dart';
import '../theme/app_theme.dart';

Future<void> showWeeklyTaskSheet(BuildContext context,
    {WeeklyTask? task}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _WeeklyTaskSheet(
        task: task, service: context.read<WeeklyTaskService>()),
  );
}

@visibleForTesting
Future<bool> confirmResetAll(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Reset all weekly tasks?'),
      content: const Text(
          'Reset progress for all weekly tasks to zero? Task definitions will be kept.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Reset all')),
      ],
    ),
  );
  return confirmed == true;
}

@visibleForTesting
Future<bool> confirmDeleteWeeklyTask(BuildContext context, String title) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete weekly task?'),
      content: Text('Delete "$title"? This cannot be undone.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete')),
      ],
    ),
  );
  return confirmed == true;
}

@visibleForTesting
Future<bool> confirmDeleteAllWeeklyTasks(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete all weekly tasks?'),
      content: const Text(
          'This will permanently remove all weekly tasks. This cannot be undone.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete all')),
      ],
    ),
  );
  return confirmed == true;
}

class _WeeklyTaskSheet extends StatefulWidget {
  const _WeeklyTaskSheet({required this.task, required this.service});
  final WeeklyTask? task;
  final WeeklyTaskService service;

  @override
  State<_WeeklyTaskSheet> createState() => _WeeklyTaskSheetState();
}

class _WeeklyTaskSheetState extends State<_WeeklyTaskSheet> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title =
      TextEditingController(text: widget.task?.title);
  late final TextEditingController _description =
      TextEditingController(text: widget.task?.description);
  late final TextEditingController _target =
      TextEditingController(text: '${widget.task?.targetPerWeek ?? 7}');
  late final TextEditingController _done =
      TextEditingController(text: '${widget.task?.doneThisWeek ?? 0}');
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _target.dispose();
    _done.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    try {
      await widget.service.save(WeeklyTask(
        id: widget.task?.id,
        title: _title.text.trim(),
        description: _description.text.trim(),
        targetPerWeek: int.parse(_target.text),
        doneThisWeek: int.parse(_done.text),
        weekKey: widget.task?.weekKey ?? weeklyKey(DateTime.now()),
        history: widget.task?.history,
      ));
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not save weekly task: $error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 12, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
        child: Form(
            key: _form,
            child: SingleChildScrollView(
                child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                    widget.task == null
                        ? 'Add Weekly Task'
                        : 'Edit Weekly Task',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 20),
                TextFormField(
                    controller: _title,
                    decoration: const InputDecoration(labelText: 'Title'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Title is required'
                        : null),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _description,
                    decoration: const InputDecoration(
                        labelText: 'Description (optional)'),
                    maxLines: 2),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _target,
                    decoration:
                        const InputDecoration(labelText: 'Target per week'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) => (int.tryParse(value ?? '') ?? 0) < 1
                        ? 'Enter a target greater than zero'
                        : null),
                if (widget.task != null) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                      controller: _done,
                      decoration:
                          const InputDecoration(labelText: 'Done this week'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (value) {
                        final done = int.tryParse(value ?? '');
                        final target = int.tryParse(_target.text);
                        return done == null ||
                                done < 0 ||
                                target == null ||
                                done > target
                            ? 'Enter a count between 0 and the target'
                            : null;
                      }),
                ],
                const SizedBox(height: 20),
                FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'Saving…' : 'Save weekly task')),
              ],
            ))),
      );
}

class WeeklyTasksScreen extends StatefulWidget {
  const WeeklyTasksScreen({super.key});

  @override
  State<WeeklyTasksScreen> createState() => _WeeklyTasksScreenState();
}

class _WeeklyTasksScreenState extends State<WeeklyTasksScreen> {
  bool _bulkRunning = false;

  Future<void> _resetAll() async {
    if (_bulkRunning) return;
    final service = context.read<WeeklyTaskService>();
    final tasks = service.getAll();
    if (tasks.isEmpty) return;
    final confirmed = await confirmResetAll(context);
    if (!confirmed || !mounted) return;
    setState(() => _bulkRunning = true);
    try {
      for (final task in tasks) {
        await service.save(task.copyWith(doneThisWeek: 0));
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All weekly tasks reset.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Reset failed: $error')));
      }
    } finally {
      if (mounted) setState(() => _bulkRunning = false);
    }
  }

  Future<void> _deleteTask(String id, String title) async {
    if (_bulkRunning) return;
    final confirmed = await confirmDeleteWeeklyTask(context, title);
    if (!confirmed || !mounted) return;
    setState(() => _bulkRunning = true);
    try {
      await context.read<WeeklyTaskService>().delete(id);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Deleted "$title".')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Delete failed: $error')));
      }
    } finally {
      if (mounted) setState(() => _bulkRunning = false);
    }
  }

  Future<void> _deleteAll() async {
    if (_bulkRunning) return;
    final service = context.read<WeeklyTaskService>();
    final tasks = service.getAll();
    if (tasks.isEmpty) return;
    final confirmed = await confirmDeleteAllWeeklyTasks(context);
    if (!confirmed || !mounted) return;
    setState(() => _bulkRunning = true);
    try {
      for (final task in tasks) {
        await service.delete(task.id);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All weekly tasks deleted.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Delete all failed: $error')));
      }
    } finally {
      if (mounted) setState(() => _bulkRunning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<WeeklyTaskService>();
    final tasks = service.getAll();
    return ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 112),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                    'Week of ${weeklyKey(DateTime.now())} (Saturday – Friday)',
                    style: const TextStyle(
                        color: AppTheme.cyan, fontWeight: FontWeight.w600)),
              ),
              if (tasks.isNotEmpty) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _bulkRunning ? null : _resetAll,
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.cyan,
                  ),
                  child: const Text('Reset all'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _bulkRunning ? null : _deleteAll,
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.failed,
                  ),
                  child: const Text('Delete all'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          if (tasks.isEmpty)
            const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                    child: Text('No weekly tasks yet',
                        style: TextStyle(color: Colors.white60)))),
          for (final task in tasks)
            Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  decoration: AppTheme.neonCard(accent: AppTheme.cyan),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                              child: Text(task.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700))),
                          IconButton(
                              tooltip: 'Edit weekly task',
                              onPressed: _bulkRunning
                                  ? null
                                  : () =>
                                      showWeeklyTaskSheet(context, task: task),
                              icon: const Icon(Icons.edit_outlined,
                                  color: AppTheme.cyan)),
                          IconButton(
                              tooltip: 'Delete ${task.title}',
                              onPressed: _bulkRunning
                                  ? null
                                  : () => _deleteTask(task.id, task.title),
                              icon: const Icon(Icons.delete_outline_rounded,
                                  color: AppTheme.failed)),
                        ]),
                        if (task.description.isNotEmpty)
                          Text(task.description,
                              style: const TextStyle(color: Colors.white70)),
                        const SizedBox(height: 12),
                        Row(children: [
                          IconButton(
                              tooltip: 'Decrease ${task.title}',
                              onPressed: task.doneThisWeek == 0
                                  ? null
                                  : () => service.adjust(task.id, -1),
                              icon: const Icon(Icons.remove_circle_outline)),
                          Expanded(
                              child: Text(
                                  '${task.doneThisWeek} / ${task.targetPerWeek}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: AppTheme.cyan,
                                      fontWeight: FontWeight.bold))),
                          IconButton(
                              tooltip: 'Increase ${task.title}',
                              onPressed: task.doneThisWeek >= task.targetPerWeek
                                  ? null
                                  : () => service.adjust(task.id, 1),
                              icon: const Icon(Icons.add_circle_outline)),
                        ]),
                        const SizedBox(height: 8),
                        LayoutBuilder(
                          builder: (context, constraints) => ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                height: 9,
                                color: AppTheme.background,
                                alignment: Alignment.centerLeft,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 240),
                                  height: 9,
                                  width: constraints.maxWidth *
                                      task.doneThisWeek /
                                      task.targetPerWeek,
                                  decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                    colors: [AppTheme.cyan, AppTheme.purple],
                                  )),
                                ),
                              )),
                        ),
                      ]),
                )),
        ]);
  }
}
