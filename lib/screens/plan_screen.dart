import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../services/plan_export.dart';
import '../services/plan_service.dart';
import '../services/week_cycle_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'add_task_bottom_sheet.dart';
import 'week_setup_screen.dart';

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
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _PlanTypeSheet(
      onUniversity: () => Navigator.pop(sheetContext, true),
      onEtc: () => Navigator.pop(sheetContext, false),
    ),
  );
  if (university == null || !context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PlanEditor(university: university),
  );
}

class _PlanTypeSheet extends StatelessWidget {
  const _PlanTypeSheet({required this.onUniversity, required this.onEtc});

  final VoidCallback onUniversity;
  final VoidCallback onEtc;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xF20B1738), Color(0xF7071028)],
              ),
              border: Border(
                top: BorderSide(color: AppTheme.blue.withValues(alpha: 0.7)),
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF8EA4BE),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Choose a plan type',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _PlanTypeOption(
                      icon: Icons.school_outlined,
                      accent: AppTheme.cyan,
                      title: 'University',
                      description: 'Schedule classes for Z, F, or both weeks',
                      onTap: onUniversity,
                    ),
                    const SizedBox(height: 12),
                    _PlanTypeOption(
                      icon: Icons.edit_calendar_outlined,
                      accent: AppTheme.purple,
                      title: 'ETC',
                      description: 'Create and name your own weekly plan',
                      onTap: onEtc,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

class _PlanTypeOption extends StatefulWidget {
  const _PlanTypeOption({
    required this.icon,
    required this.accent,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  State<_PlanTypeOption> createState() => _PlanTypeOptionState();
}

class _PlanTypeOptionState extends State<_PlanTypeOption> {
  bool _highlighted = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
        onEnter: (_) => setState(() => _highlighted = true),
        onExit: (_) => setState(() => _highlighted = false),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _highlighted = true),
          onTapCancel: () => setState(() => _highlighted = false),
          onTapUp: (_) => setState(() => _highlighted = false),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xCC122448),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color:
                    widget.accent.withValues(alpha: _highlighted ? 0.95 : 0.4),
                width: _highlighted ? 1.4 : 1,
              ),
              boxShadow: _highlighted
                  ? [
                      BoxShadow(
                        color: widget.accent.withValues(alpha: 0.28),
                        blurRadius: 16,
                      ),
                    ]
                  : null,
            ),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: widget.accent.withValues(alpha: 0.14),
                  border:
                      Border.all(color: widget.accent.withValues(alpha: 0.75)),
                ),
                child: Icon(widget.icon, color: widget.accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.description,
                      style: const TextStyle(
                        color: Color(0xFF9BB0C9),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ]),
          ),
        ),
      );
}

class PlanWeekPrompt extends StatefulWidget {
  const PlanWeekPrompt({super.key, required this.child});

  final Widget child;

  @override
  State<PlanWeekPrompt> createState() => _PlanWeekPromptState();
}

class _PlanWeekPromptState extends State<PlanWeekPrompt> {
  var _asked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ask());
  }

  Future<void> _ask() async {
    if (_asked || !mounted) return;
    final cycle = _watchWeekCycle(context, listen: false);
    if (cycle == null || cycle.isConfigured) return;
    _asked = true;
    await showWeekCycleDialog(context, cycle, requiredChoice: true);
  }

  @override
  Widget build(BuildContext context) => widget.child;
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
  Widget build(BuildContext context) {
    final cycle = _watchWeekCycle(context);
    return PlanWeekPrompt(
      child: Consumer<PlanService>(
        builder: (context, service, _) {
          final plans = service.plans;
          final activeCycle =
              cycle != null && cycle.isConfigured ? cycle : null;
          if (plans.isEmpty) {
            return Column(children: [
              if (activeCycle != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 0),
                  child: PlanWeekBanner(cycle: activeCycle),
                ),
              const Expanded(
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.event_note_outlined,
                        color: AppTheme.cyan, size: 50),
                    SizedBox(height: 12),
                    Text('No plans yet. Tap Add Plan to get started.',
                        style: TextStyle(color: Colors.white70)),
                  ]),
                ),
              ),
            ]);
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 108),
            itemCount: plans.length + (activeCycle != null ? 1 : 0),
            itemBuilder: (context, index) {
              if (activeCycle != null && index == 0) {
                return PlanWeekBanner(cycle: activeCycle);
              }
              final plan = plans[index - (activeCycle != null ? 1 : 0)];
              final now = DateTime.now();
              final odd = cycle != null && cycle.isConfigured
                  ? cycle.isOddOn(now)
                  : plan.isOddOn(now);
              final visible = plan.entries
                  .where((entry) => planEntryRunsThisWeek(
                        everyWeek: !plan.university,
                        weeks: entry.weeks,
                        oddWeek: odd,
                      ))
                  .toList();
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
                    PlanExportButton(plan: plan),
                    IconButton(
                      tooltip: 'Edit Plan',
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
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
                      ? WeekParity.fromOdd(odd).englishWeekLabel
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
                        segments: [
                          ButtonSegment(
                              value: WeekParity.odd.isOdd,
                              label: Text(WeekParity.odd.code)),
                          ButtonSegment(
                              value: WeekParity.even.isOdd,
                              label: Text(WeekParity.even.code)),
                        ],
                        selected: {odd},
                        onSelectionChanged: (value) async {
                          try {
                            if (cycle != null && cycle.isConfigured) {
                              await cycle.chooseCurrentWeek(value.first);
                            } else {
                              await service.setCurrentWeek(plan, value.first);
                            }
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
                    if (visible.isEmpty)
                      const Text('No tasks this week.',
                          style: TextStyle(color: Colors.white70))
                    else
                      for (final entry in visible)
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
      ),
    );
  }
}

class PlanWeekBanner extends StatelessWidget {
  const PlanWeekBanner({super.key, required this.cycle});

  final WeekCycleService cycle;

  @override
  Widget build(BuildContext context) {
    final odd = cycle.isOddOn(DateTime.now());
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
      decoration: AppTheme.neonCard(accent: AppTheme.cyan),
      child: Row(children: [
        Expanded(
          child: Text(
            WeekParity.fromOdd(odd).englishCurrentLabel,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Change week',
          icon: const Icon(Icons.edit_outlined),
          onPressed: () => showWeekCycleDialog(context, cycle),
        ),
      ]),
    );
  }
}

WeekCycleService? _watchWeekCycle(BuildContext context, {bool listen = true}) {
  try {
    return Provider.of<WeekCycleService>(context, listen: listen);
  } on ProviderNotFoundException {
    return null;
  }
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

class PlanExportButton extends StatefulWidget {
  const PlanExportButton({super.key, required this.plan, this.copyText});

  final PlanDefinition plan;
  final Future<void> Function(String text)? copyText;

  @override
  State<PlanExportButton> createState() => _PlanExportButtonState();
}

class _PlanExportButtonState extends State<PlanExportButton> {
  bool _busy = false;

  Future<void> _copy() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final now = DateTime.now();
      final document = buildPlanExport(
        widget.plan,
        exportedAt: now,
        timeZoneOffset: now.timeZoneOffset,
      );
      final json = encodePlanExport(document);
      final copy = widget.copyText ??
          (String text) => Clipboard.setData(ClipboardData(text: text));
      await copy(json);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Plan JSON copied to clipboard'),
          action: SnackBarAction(
            label: 'Preview',
            onPressed: () => _showPreview(json),
          ),
        ),
      );
    } on PlanExportException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showPreview(String json) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Plan JSON'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(child: SelectableText(json)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () async {
              final copy = widget.copyText ??
                  (String text) => Clipboard.setData(ClipboardData(text: text));
              await copy(json);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Copy'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'Export JSON',
        visualDensity: VisualDensity.compact,
        onPressed: _busy ? null : _copy,
        icon: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.share_outlined, size: 20),
      );
}

String _entryLabel(PlanEntry entry, bool university) =>
    '${_days[entry.weekday - 1]} · ${_clock(entry.startSecond)}–${_clock(entry.endSecond)}${university ? ' · ${WeekParity.fromStorage(entry.weeks)?.code ?? 'Z / F'}' : ''}';

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
    final cycle = _watchWeekCycle(context, listen: false);
    if (cycle != null && cycle.isConfigured) {
      odd = cycle.isOddOn(DateTime.now());
    } else if (widget.university && widget.initial == null) {
      final selected = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Is this week Z or F?'),
          content: const Text(
              'The plan will alternate automatically each Saturday.'),
          actions: [
            TextButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, WeekParity.even.isOdd),
                child: Text(WeekParity.even.code)),
            FilledButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, WeekParity.odd.isOdd),
                child: Text(WeekParity.odd.code)),
          ],
        ),
      );
      if (selected == null || !mounted) return;
      odd = selected;
    }
    final planService = context.read<PlanService>();
    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      if (cycle != null && !cycle.isConfigured) {
        await cycle.chooseCurrentWeek(odd, now: now);
      }
      await planService.save(PlanDefinition(
        id: widget.initial?.id ?? const Uuid().v4(),
        name: _name.text.trim(),
        university: widget.university,
        anchorMonday: widget.initial?.anchorMonday ??
            DateTime(now.year, now.month, now.day)
                .subtract(Duration(days: now.weekday - 1)),
        anchorSaturday: widget.initial?.anchorSaturday ??
            (cycle != null && cycle.isConfigured
                ? cycle.anchorSaturday
                : saturdayStartingWeek(now)),
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
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottomInset = media.viewInsets.bottom;
    final title =
        '${widget.initial == null ? 'Add' : 'Edit'} ${widget.university ? 'University' : 'ETC'} Plan';
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xF20B1738), Color(0xF7071028)],
              ),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: media.size.height * 0.92 - bottomInset,
              ),
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                      20, 10, 20, bottomInset == 0 ? 18 : 12),
                  child: Column(children: [
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF8EA4BE),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _name,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      decoration: _planNameDecoration(),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _entries.isEmpty
                          ? const Center(
                              child: Text(
                                'Add tasks to weekdays.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFF9BB0C9),
                                  fontSize: 15,
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _entries.length,
                              itemBuilder: (context, index) {
                                final entry = _entries[index];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xCC122448),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color:
                                          AppTheme.cyan.withValues(alpha: 0.35),
                                    ),
                                  ),
                                  child: ListTile(
                                    title: Text(entry.title,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700)),
                                    subtitle: Text(
                                      _entryLabel(entry, widget.university),
                                      style: const TextStyle(
                                          color: Color(0xFF9BB0C9)),
                                    ),
                                    onTap: () => _addEntry(old: entry),
                                    trailing: IconButton(
                                      tooltip: 'Remove task',
                                      icon: const Icon(Icons.close_rounded,
                                          color: Color(0xFF9BB0C9)),
                                      onPressed: () => setState(
                                          () => _entries.remove(entry)),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                        child: _PlanAddTaskButton(
                      enabled: !_saving,
                      onPressed: _addEntry,
                    )),
                    const SizedBox(height: 12),
                    _PlanCreateButton(
                      saving: _saving,
                      label:
                          widget.initial == null ? 'Create plan' : 'Save plan',
                      onPressed: _save,
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

InputDecoration _planNameDecoration() {
  const radius = BorderRadius.all(Radius.circular(18));
  return InputDecoration(
    labelText: 'Plan name',
    prefixIcon:
        const Icon(Icons.drive_file_rename_outline, color: AppTheme.cyan),
    filled: true,
    fillColor: const Color(0xE6162A4A),
    labelStyle: const TextStyle(color: Color(0xFF8EA4BE)),
    floatingLabelStyle: const TextStyle(color: Color(0xFFD5E4F5)),
    enabledBorder: const OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: Color(0xFF3E6F9E)),
    ),
    focusedBorder: const OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: AppTheme.cyan, width: 1.6),
    ),
  );
}

class _PlanAddTaskButton extends StatefulWidget {
  const _PlanAddTaskButton({required this.enabled, required this.onPressed});
  final bool enabled;
  final VoidCallback onPressed;

  @override
  State<_PlanAddTaskButton> createState() => _PlanAddTaskButtonState();
}

class _PlanAddTaskButtonState extends State<_PlanAddTaskButton> {
  bool _hot = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
        onEnter: (_) => setState(() => _hot = true),
        onExit: (_) => setState(() => _hot = false),
        child: OutlinedButton.icon(
          onPressed: widget.enabled ? widget.onPressed : null,
          onHover: (value) => setState(() => _hot = value),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.purple,
            disabledForegroundColor: AppTheme.purple.withValues(alpha: 0.4),
            backgroundColor: const Color(0x33122448),
            side: BorderSide(
              color: AppTheme.purple
                  .withValues(alpha: _hot && widget.enabled ? 1 : 0.65),
              width: _hot && widget.enabled ? 1.4 : 1,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            shadowColor: AppTheme.purple.withValues(alpha: 0.4),
            elevation: _hot && widget.enabled ? 2 : 0,
          ),
          icon: const Icon(Icons.add, color: AppTheme.purple),
          label: const Text('Add task to day',
              style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      );
}

class _PlanCreateButton extends StatelessWidget {
  const _PlanCreateButton({
    required this.saving,
    required this.label,
    required this.onPressed,
  });

  final bool saving;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: saving
              ? null
              : const LinearGradient(
                  colors: [AppTheme.blue, AppTheme.purple],
                ),
          color: saving ? const Color(0xFF1A2C4A) : null,
          boxShadow: saving
              ? null
              : [
                  BoxShadow(
                    color: AppTheme.purple.withValues(alpha: 0.32),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: saving ? null : onPressed,
            child: SizedBox(
              height: 52,
              width: double.infinity,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white70,
                          ),
                        )
                      : const Icon(Icons.save_outlined, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      color: saving ? Colors.white70 : Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
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
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xF20B1738), Color(0xF7071028)],
              ),
              border: Border.all(color: AppTheme.blue.withValues(alpha: 0.7)),
              borderRadius: BorderRadius.circular(24),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 420,
                maxHeight: media.size.height - media.padding.vertical - 48,
              ),
              child: SingleChildScrollView(
                padding:
                    EdgeInsets.fromLTRB(20, 20, 20, 16 + media.padding.bottom),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.initial == null ? 'Choose a day' : 'Edit schedule',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 18),
                    DropdownButtonFormField<int>(
                      initialValue: _weekday,
                      isExpanded: true,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded,
                          color: AppTheme.cyan),
                      dropdownColor: const Color(0xFF132448),
                      borderRadius: BorderRadius.circular(16),
                      decoration: _planMenuField('Day of week'),
                      items: [
                        for (var i = 1; i <= 7; i++)
                          DropdownMenuItem(
                            value: i,
                            child: Text(_days[i - 1],
                                overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _weekday = value);
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _weeks,
                      isExpanded: true,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded,
                          color: AppTheme.purple),
                      dropdownColor: const Color(0xFF132448),
                      borderRadius: BorderRadius.circular(16),
                      decoration: _planMenuField('Weeks'),
                      items: const [
                        DropdownMenuItem(
                          value: 'even',
                          child: Text('Z · Even · هفته زوج',
                              overflow: TextOverflow.ellipsis),
                        ),
                        DropdownMenuItem(
                          value: 'odd',
                          child: Text('F · Odd · هفته فرد',
                              overflow: TextOverflow.ellipsis),
                        ),
                        DropdownMenuItem(
                          value: 'both',
                          child: Text('Z / F weeks',
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _weeks = value);
                      },
                    ),
                    const SizedBox(height: 22),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.purple,
                      ),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(height: 8),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          colors: [AppTheme.purple, Color(0xFF6D28D9)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.purple.withValues(alpha: 0.32),
                            blurRadius: 14,
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => Navigator.pop(context, (
                            weekday: _weekday,
                            weeks: _weeks,
                          )),
                          child: const SizedBox(
                            height: 48,
                            child: Center(
                              child: Text(
                                'Next: task details',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

InputDecoration _planMenuField(String label) {
  const radius = BorderRadius.all(Radius.circular(18));
  return InputDecoration(
    labelText: label,
    filled: true,
    fillColor: const Color(0xE6162A4A),
    labelStyle: const TextStyle(color: Color(0xFF8EA4BE)),
    floatingLabelStyle: const TextStyle(color: Color(0xFFD5E4F5)),
    contentPadding: const EdgeInsets.fromLTRB(16, 20, 12, 16),
    enabledBorder: const OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: Color(0xFF3E6F9E)),
    ),
    focusedBorder: const OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: AppTheme.cyan, width: 1.6),
    ),
  );
}
