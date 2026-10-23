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

class WeeklyTasksScreen extends StatelessWidget {
  const WeeklyTasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<WeeklyTaskService>();
    final tasks = service.getAll();
    return ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 112),
        children: [
          Text('Week of ${weeklyKey(DateTime.now())} (Saturday – Friday)',
              style: const TextStyle(
                  color: AppTheme.cyan, fontWeight: FontWeight.w600)),
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
                              onPressed: () =>
                                  showWeeklyTaskSheet(context, task: task),
                              icon: const Icon(Icons.edit_outlined,
                                  color: AppTheme.cyan)),
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
