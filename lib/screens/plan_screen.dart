import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../services/plan_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'add_task_bottom_sheet.dart';

const _days = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday'
];

Future<void> showAddPlanFlow(BuildContext context) async {
  final university = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Choose a plan type',
              style: Theme.of(sheetContext).textTheme.titleLarge),
          const SizedBox(height: 14),
          ListTile(
            leading: const Icon(Icons.school_outlined, color: AppTheme.cyan),
            title: const Text('University'),
            subtitle: const Text('Schedule classes for Z, F, or both weeks'),
            onTap: () => Navigator.pop(sheetContext, true),
          ),
          ListTile(
            leading: const Icon(Icons.edit_calendar_outlined,
                color: AppTheme.purple),
            title: const Text('ETC'),
            subtitle: const Text('Create and name your own weekly plan'),
            onTap: () => Navigator.pop(sheetContext, false),
          ),
        ]),
      ),
    ),
  );
  if (university == null || !context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _PlanEditor(university: university),
  );
}

class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key});

  Future<void> _confirmDeletePlan(
      BuildContext context, PlanService service, PlanDefinition plan) async {
    final confirmed = await confirmDeletePlan(context, plan.name);
    if (confirmed != true || !context.mounted) return;
    try {
      await service.deletePlan(plan.id);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete plan: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Consumer<PlanService>(
        builder: (context, service, _) {
          final plans = service.plans;
          if (plans.isEmpty) {
            return const Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.event_note_outlined, color: AppTheme.cyan, size: 50),
                SizedBox(height: 12),
                Text('No plans yet. Tap Add Plan to get started.',
                    style: TextStyle(color: Colors.white70)),
              ]),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 108),
            itemCount: plans.length,
            itemBuilder: (context, index) {
              final plan = plans[index];
              final odd = plan.isOddOn(DateTime.now());
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: AppTheme.neonCard(
                    accent: plan.university ? AppTheme.cyan : AppTheme.purple),
                child: ExpansionTile(
                  leading: Icon(
                      plan.university
                          ? Icons.school_outlined
                          : Icons.edit_calendar_outlined,
                      color: AppTheme.cyan),
                  title: Row(children: [
                    Expanded(
                        child: Text(plan.name,
                            maxLines: 1, overflow: TextOverflow.ellipsis)),
                    IconButton(
                      tooltip: 'Edit Plan',
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        showDragHandle: true,
                        builder: (_) => _PlanEditor(
                            university: plan.university, initial: plan),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Delete Plan',
                      icon: const Icon(Icons.delete_outline_rounded, size: 20),
                      onPressed: () =>
                          _confirmDeletePlan(context, service, plan),
                    ),
                  ]),
                  subtitle: Text(plan.university
                      ? (odd ? 'Z week' : 'F week')
                      : 'ETC · Every week'),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  children: [
                    if (plan.university) ...[
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Current week',
                            style: TextStyle(color: Colors.white70)),
                      ),
                      const SizedBox(height: 6),
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: true, label: Text('Z')),
                          ButtonSegment(value: false, label: Text('F')),
                        ],
                        selected: {odd},
                        onSelectionChanged: (value) async {
                          try {
                            await service.setCurrentWeek(plan, value.first);
                          } catch (error) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content:
                                        Text('Could not change week: $error')),
                              );
                            }
                          }
                        },
                      ),
                      const Divider(height: 24),
                    ],
                    for (final entry in plan.entries)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.checklist_rounded,
                            color: AppTheme.purple),
                        title: Text(entry.title),
                        subtitle: Text(_entryLabel(entry, plan.university)),
                      ),
                  ],
                ),
              );
            },
          );
        },
      );
}

@visibleForTesting
Future<bool> confirmDeletePlan(BuildContext context, String planName) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete plan?'),
      content: Text(
          'Delete $planName and all tasks generated by this plan? Scheduled reminders and alarms will be cancelled.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete plan')),
      ],
    ),
  );
  return confirmed == true;
}

String _entryLabel(PlanEntry entry, bool university) =>
    '${_days[entry.weekday - 1]} · ${_clock(entry.startSecond)}–${_clock(entry.endSecond)}${university ? ' · ${entry.weeks == 'odd' ? 'Z' : entry.weeks == 'even' ? 'F' : 'Z / F'}' : ''}';

String _clock(int seconds) => DateFormat('HH:mm')
    .format(DateTime(2000, 1, 1).add(Duration(seconds: seconds)));

class _PlanEditor extends StatefulWidget {
  const _PlanEditor({required this.university, this.initial});
  final bool university;
  final PlanDefinition? initial;

  @override
  State<_PlanEditor> createState() => _PlanEditorState();
}

class _PlanEditorState extends State<_PlanEditor> {
  final _name = TextEditingController();
  final _entries = <PlanEntry>[];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name.text =
        widget.initial?.name ?? (widget.university ? 'University' : '');
    _entries.addAll(widget.initial?.entries ?? const []);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _addEntry({PlanEntry? old}) async {
    final schedule = await showDialog<_PlanSchedule>(
      context: context,
      builder: (_) =>
          _PlanEntryDialog(university: widget.university, initial: old),
    );
    if (schedule == null || !mounted) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day =
        today.add(Duration(days: (schedule.weekday - today.weekday + 7) % 7));
    final storage = context.read<StorageService>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => AddTaskBottomSheet(
        storage: storage,
        task: old?.taskOn(day, id: old.id),
        templateDate: day,
        onSaveTemplate: (task) async {
          final entry = PlanEntry.fromTask(task,
              id: old?.id ?? const Uuid().v4(),
              weekday: schedule.weekday,
              weeks: schedule.weeks);
          if (!mounted) return;
          setState(() {
            if (old != null) _entries.remove(old);
            _entries.add(entry);
            _entries.sort((a, b) => a.weekday.compareTo(b.weekday));
          });
        },
      ),
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_name.text.trim().isEmpty || _entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Enter a plan name and add at least one task.')),
      );
      return;
    }
    var odd = true;
    if (widget.university && widget.initial == null) {
      final selected = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Is this week Z or F?'),
          content:
              const Text('The plan will alternate automatically each Monday.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('F')),
            FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Z')),
          ],
        ),
      );
      if (selected == null || !mounted) return;
      odd = selected;
    }
    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      await context.read<PlanService>().save(PlanDefinition(
            id: widget.initial?.id ?? const Uuid().v4(),
            name: _name.text.trim(),
            university: widget.university,
            anchorMonday: widget.initial?.anchorMonday ??
                DateTime(now.year, now.month, now.day)
                    .subtract(Duration(days: now.weekday - 1)),
            anchorOdd: widget.initial?.anchorOdd ?? odd,
            entries: List.unmodifiable(_entries),
          ));
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save plan: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.85),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(
                    '${widget.initial == null ? 'Add' : 'Edit'} ${widget.university ? 'University' : 'ETC'} Plan',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 14),
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(
                      labelText: 'Plan name',
                      prefixIcon: Icon(Icons.drive_file_rename_outline)),
                ),
                const SizedBox(height: 12),
                Expanded(
                    child: _entries.isEmpty
                        ? const Center(
                            child: Text('Add tasks to weekdays.',
                                style: TextStyle(color: Colors.white70)))
                        : ListView.builder(
                            itemCount: _entries.length,
                            itemBuilder: (context, index) {
                              final entry = _entries[index];
                              return Card(
                                child: ListTile(
                                  title: Text(entry.title),
                                  subtitle: Text(
                                      _entryLabel(entry, widget.university)),
                                  onTap: () => _addEntry(old: entry),
                                  trailing: IconButton(
                                    tooltip: 'Remove task',
                                    icon: const Icon(Icons.close_rounded),
                                    onPressed: () =>
                                        setState(() => _entries.remove(entry)),
                                  ),
                                ),
                              );
                            },
                          )),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _addEntry,
                  icon: const Icon(Icons.add),
                  label: const Text('Add task to day'),
                ),
                const SizedBox(height: 8),
                SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.save_outlined),
                      label: Text(
                          widget.initial == null ? 'Create plan' : 'Save plan'),
                    )),
              ]),
            ),
          ),
        ),
      );
}

typedef _PlanSchedule = ({int weekday, String weeks});

class _PlanEntryDialog extends StatefulWidget {
  const _PlanEntryDialog({required this.university, this.initial});
  final bool university;
  final PlanEntry? initial;

  @override
  State<_PlanEntryDialog> createState() => _PlanEntryDialogState();
}

class _PlanEntryDialogState extends State<_PlanEntryDialog> {
  late int _weekday;
  late String _weeks;

  @override
  void initState() {
    super.initState();
    _weekday = widget.initial?.weekday ?? DateTime.now().weekday;
    _weeks = widget.initial?.weeks ?? 'both';
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.initial == null ? 'Choose a day' : 'Edit schedule'),
        content: SizedBox(
          width: 400,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<int>(
              initialValue: _weekday,
              decoration: const InputDecoration(labelText: 'Day of week'),
              items: [
                for (var i = 1; i <= 7; i++)
                  DropdownMenuItem(value: i, child: Text(_days[i - 1]))
              ],
              onChanged: (value) {
                if (value != null) setState(() => _weekday = value);
              },
            ),
            if (widget.university)
              DropdownButtonFormField<String>(
                initialValue: _weeks,
                decoration: const InputDecoration(labelText: 'Weeks'),
                items: const [
                  DropdownMenuItem(value: 'odd', child: Text('Z weeks')),
                  DropdownMenuItem(value: 'even', child: Text('F weeks')),
                  DropdownMenuItem(value: 'both', child: Text('Z / F weeks')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _weeks = value);
                },
              ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, (
              weekday: _weekday,
              weeks: widget.university ? _weeks : 'both'
            )),
            child: const Text('Next: task details'),
          ),
        ],
      );
}
