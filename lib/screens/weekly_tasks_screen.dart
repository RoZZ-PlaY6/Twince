import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/weekly_task_service.dart';
import '../services/weekly_tasks_clipboard.dart';
import '../theme/app_theme.dart';

Future<String?> showWeeklyCategoryDialog(BuildContext context) {
  final name = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: _weeklyNavy,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: AppTheme.blue.withValues(alpha: 0.7)),
      ),
      title: const Text('New category',
          style: TextStyle(fontWeight: FontWeight.w700)),
      content: TextField(
        controller: name,
        autofocus: true,
        style: const TextStyle(color: Colors.white),
        decoration:
            _weeklyFieldDecoration('Category name', Icons.folder_outlined),
        textInputAction: TextInputAction.done,
        onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, name.text.trim()),
          child: const Text('Create'),
        ),
      ],
    ),
  ).whenComplete(name.dispose);
}

Future<void> showWeeklyTaskSheet(BuildContext context,
    {WeeklyTask? task}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.transparent,
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
  late String _categoryId = widget.service
          .getCategories()
          .any((category) => category.id == widget.task?.categoryId)
      ? widget.task!.categoryId!
      : '';
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
        categoryId: _categoryId.isEmpty ? null : _categoryId,
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
  Widget build(BuildContext context) {
    final adding = widget.task == null;
    return ClipRRect(
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
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                20, 4, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
            child: Form(
              key: _form,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _WeeklyFormHeader(adding: adding),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: _title,
                      style: _weeklyInputStyle,
                      textInputAction: TextInputAction.next,
                      decoration: _weeklyFieldDecoration(
                          'Title', Icons.short_text_rounded),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Title is required'
                              : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _description,
                      style: _weeklyInputStyle,
                      decoration: _weeklyFieldDecoration(
                          'Description (optional)', Icons.notes_outlined),
                      maxLines: 3,
                      minLines: 2,
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      key: ValueKey(
                          '$_categoryId-${widget.service.getCategories().length}'),
                      isExpanded: true,
                      initialValue: _categoryId,
                      style: _weeklyInputStyle,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded,
                          color: AppTheme.cyan),
                      dropdownColor: const Color(0xFF132448),
                      borderRadius: BorderRadius.circular(16),
                      decoration: _weeklyFieldDecoration(
                          'Category', Icons.sell_outlined),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text(uncategorizedWeeklyLabel),
                        ),
                        for (final category in widget.service.getCategories())
                          DropdownMenuItem(
                            value: category.id,
                            child: Text(category.name),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _categoryId = value);
                      },
                    ),
                    if (_categoryId.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: TextButton.icon(
                          onPressed: _saving
                              ? null
                              : () => setState(() => _categoryId = ''),
                          icon: const Icon(Icons.folder_off_outlined),
                          label: const Text('Remove from category'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _target,
                      style: _weeklyInputStyle,
                      decoration: _weeklyFieldDecoration(
                          'Target per week', Icons.flag_outlined),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (value) => (int.tryParse(value ?? '') ?? 0) < 1
                          ? 'Enter a target greater than zero'
                          : null,
                    ),
                    if (widget.task != null) ...[
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _done,
                        style: _weeklyInputStyle,
                        decoration: _weeklyFieldDecoration(
                            'Done this week', Icons.check_circle_outline),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        validator: (value) {
                          final done = int.tryParse(value ?? '');
                          final target = int.tryParse(_target.text);
                          return done == null ||
                                  done < 0 ||
                                  target == null ||
                                  done > target
                              ? 'Enter a count between 0 and the target'
                              : null;
                        },
                      ),
                    ],
                    const SizedBox(height: 22),
                    _WeeklySaveButton(saving: _saving, onPressed: _save),
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

const _weeklyNavy = Color(0xFF0B1738);
const _weeklyInputStyle = TextStyle(color: Colors.white, fontSize: 16);

InputDecoration _weeklyFieldDecoration(String label, IconData icon) {
  const radius = BorderRadius.all(Radius.circular(18));
  const muted = Color(0xFF8EA4BE);
  return InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, size: 20, color: AppTheme.purple),
    filled: true,
    fillColor: const Color(0xE6162A4A),
    labelStyle: const TextStyle(color: muted),
    floatingLabelStyle: const TextStyle(color: Color(0xFFD5E4F5)),
    hintStyle: const TextStyle(color: muted),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    enabledBorder: const OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: Color(0xFF3E6F9E)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: const BorderSide(color: AppTheme.cyan, width: 1.6),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: AppTheme.failed.withValues(alpha: 0.9)),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: const BorderSide(color: AppTheme.failed, width: 1.6),
    ),
  );
}

class _WeeklyFormHeader extends StatelessWidget {
  const _WeeklyFormHeader({required this.adding});
  final bool adding;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xCC102044),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.blue.withValues(alpha: 0.75)),
          boxShadow: [
            BoxShadow(
              color: AppTheme.blue.withValues(alpha: 0.28),
              blurRadius: 18,
            ),
          ],
        ),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                colors: [AppTheme.cyan, AppTheme.purple],
              ),
            ),
            child: Icon(adding ? Icons.add : Icons.edit_outlined,
                color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              adding ? 'Add Weekly Task' : 'Edit Weekly Task',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ]),
      );
}

class _WeeklySaveButton extends StatelessWidget {
  const _WeeklySaveButton({required this.saving, required this.onPressed});
  final bool saving;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: saving
              ? null
              : const LinearGradient(
                  colors: [AppTheme.cyan, AppTheme.blue, AppTheme.purple],
                ),
          color: saving ? const Color(0xFF1A2C4A) : null,
          boxShadow: saving
              ? null
              : [
                  BoxShadow(
                    color: AppTheme.cyan.withValues(alpha: 0.32),
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
              child: Center(
                child: saving
                    ? const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white70,
                            ),
                          ),
                          SizedBox(width: 10),
                          Text('Saving…',
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w700)),
                        ],
                      )
                    : const Text('Save weekly task',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16)),
              ),
            ),
          ),
        ),
      );
}

class WeeklyTasksScreen extends StatefulWidget {
  const WeeklyTasksScreen({
    super.key,
    this.addButtonKey,
  });

  /// The floating action button rendered by the parent HomeScreen.
  final GlobalKey? addButtonKey;

  @override
  State<WeeklyTasksScreen> createState() => _WeeklyTasksScreenState();
}

class _WeeklyTasksScreenState extends State<WeeklyTasksScreen> {
  final GlobalKey _listKey = GlobalKey();
  double _bottomClearance = 0;
  bool _bulkRunning = false;
  bool _copying = false;

  /// Null shows every category. An empty string shows only uncategorized tasks.
  String? _categoryFilter;

  void _measureBottomClearance() {
    if (!mounted || widget.addButtonKey == null) return;
    final listBox = _listKey.currentContext?.findRenderObject();
    final buttonBox = widget.addButtonKey!.currentContext?.findRenderObject();
    if (listBox is! RenderBox ||
        buttonBox is! RenderBox ||
        !listBox.hasSize ||
        !buttonBox.hasSize) {
      return;
    }
    final buttonTop =
        listBox.globalToLocal(buttonBox.localToGlobal(Offset.zero)).dy;
    final clearance = math.max(0.0, listBox.size.height - buttonTop);
    if ((clearance - _bottomClearance).abs() > 0.5) {
      setState(() => _bottomClearance = clearance);
    }
  }

  Future<void> _copyTasks() async {
    if (_copying || _bulkRunning) return;
    final service = context.read<WeeklyTaskService>();
    final tasks = service.getAll();
    if (tasks.isEmpty) return;
    final categories = service.getCategories();
    final filter = _categoryFilter != null &&
            _categoryFilter!.isNotEmpty &&
            categories.every((category) => category.id != _categoryFilter)
        ? null
        : _categoryFilter;
    final heading = filter == null
        ? 'All'
        : filter.isEmpty
            ? uncategorizedWeeklyLabel
            : service.categoryName(filter);
    final selected = filter == null
        ? tasks
        : _visibleSections(tasks, categories, filter)
            .expand((section) => section.tasks)
            .toList();
    setState(() => _copying = true);
    try {
      await copyWeeklyTasks(selected, heading: heading);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Copied to clipboard!')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Copy failed: $error')));
      }
    } finally {
      if (mounted) setState(() => _copying = false);
    }
  }

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
    final categories = service.getCategories();
    final filter = _categoryFilter != null &&
            _categoryFilter!.isNotEmpty &&
            categories.every((category) => category.id != _categoryFilter)
        ? null
        : _categoryFilter;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _measureBottomClearance());
    return ListView(
        key: _listKey,
        padding: EdgeInsets.fromLTRB(
            18, 16, 18, math.max(safeBottom, _bottomClearance) + 16),
        children: [
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Week of ${weeklyKey(DateTime.now())} (Saturday – Friday)',
                  style: const TextStyle(
                      color: AppTheme.cyan, fontWeight: FontWeight.w600)),
              if (tasks.isNotEmpty) ...[
                OutlinedButton.icon(
                  onPressed: _copying || _bulkRunning ? null : _copyTasks,
                  icon: _copying
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Copy Tasks'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.cyan,
                    side:
                        BorderSide(color: AppTheme.cyan.withValues(alpha: 0.6)),
                  ),
                ),
                TextButton(
                  onPressed: _bulkRunning ? null : _resetAll,
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.cyan,
                  ),
                  child: const Text('Reset all'),
                ),
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
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _categoryChip(
                label: 'All',
                selected: filter == null,
                onSelected: () => setState(() => _categoryFilter = null),
              ),
              _categoryChip(
                label: uncategorizedWeeklyLabel,
                selected: filter == '',
                onSelected: () => setState(() => _categoryFilter = ''),
              ),
              for (final category in categories)
                _categoryChip(
                  label: category.name,
                  selected: filter == category.id,
                  onSelected: () =>
                      setState(() => _categoryFilter = category.id),
                ),
              ActionChip(
                label: const Text('New category'),
                avatar: const Icon(Icons.add, size: 18),
                onPressed: _bulkRunning ? null : _createCategory,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (tasks.isEmpty && categories.isEmpty)
            const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                    child: Text('No weekly tasks yet',
                        style: TextStyle(color: Colors.white60)))),
          for (final section
              in _visibleSections(tasks, categories, filter)) ...[
            Row(children: [
              Expanded(
                child: Text(section.label,
                    style: const TextStyle(
                        color: AppTheme.purple, fontWeight: FontWeight.w700)),
              ),
              if (section.categoryId != null)
                IconButton(
                  tooltip: 'Delete category ${section.label}',
                  onPressed: _bulkRunning
                      ? null
                      : () =>
                          _deleteCategory(section.categoryId!, section.label),
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: AppTheme.failed, size: 20),
                ),
            ]),
            const SizedBox(height: 8),
            if (section.tasks.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text('No tasks in this category',
                    style: TextStyle(color: Colors.white60)),
              ),
            for (final task in section.tasks)
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
                                tooltip: 'Change category',
                                onPressed: _bulkRunning
                                    ? null
                                    : () => _changeCategory(task),
                                icon: const Icon(Icons.folder_outlined,
                                    color: AppTheme.cyan)),
                            IconButton(
                                tooltip: 'Edit weekly task',
                                onPressed: _bulkRunning
                                    ? null
                                    : () => showWeeklyTaskSheet(context,
                                        task: task),
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
                          Text(service.categoryName(task.categoryId),
                              style: const TextStyle(
                                  color: AppTheme.cyan, fontSize: 12)),
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
                                onPressed:
                                    task.doneThisWeek >= task.targetPerWeek
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
          ],
        ]);
  }

  Future<void> _changeCategory(WeeklyTask task) async {
    final service = context.read<WeeklyTaskService>();
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Category for ${task.title}'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              title: const Text(uncategorizedWeeklyLabel),
              onTap: () => Navigator.pop(dialogContext, ''),
            ),
            for (final category in service.getCategories())
              ListTile(
                title: Text(category.name),
                onTap: () => Navigator.pop(dialogContext, category.id),
              ),
            if (task.categoryId != null)
              ListTile(
                leading: const Icon(Icons.folder_off_outlined),
                title: const Text('Remove from category'),
                onTap: () => Navigator.pop(dialogContext, ''),
              ),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (selected == null || !mounted) return;
    await service.assignCategory(task.id, selected.isEmpty ? null : selected);
  }

  Future<void> _deleteCategory(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete category?'),
        content: Text(
            'Delete "$name"? Its weekly tasks will stay and become Uncategorized.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete category'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<WeeklyTaskService>().deleteCategory(id);
    if (!mounted) return;
    setState(() {
      if (_categoryFilter == id) _categoryFilter = null;
    });
  }

  Future<void> _createCategory() async {
    final name = await showWeeklyCategoryDialog(context);
    if (name == null || name.isEmpty || !mounted) return;
    try {
      final category =
          await context.read<WeeklyTaskService>().createCategory(name);
      if (!mounted) return;
      setState(() => _categoryFilter = category.id);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not create category: $error')));
      }
    }
  }
}

class _WeeklySection {
  const _WeeklySection(this.label, this.tasks, {this.categoryId});
  final String label;
  final String? categoryId;
  final List<WeeklyTask> tasks;
}

List<_WeeklySection> _visibleSections(
    List<WeeklyTask> tasks, List<WeeklyCategory> categories, String? filter) {
  final known = {for (final category in categories) category.id};
  final uncategorized = tasks
      .where(
          (task) => task.categoryId == null || !known.contains(task.categoryId))
      .toList();
  final sections = <_WeeklySection>[
    if (filter == null || filter.isEmpty)
      _WeeklySection(uncategorizedWeeklyLabel, uncategorized),
    for (final category in categories)
      if (filter == null || filter == category.id)
        _WeeklySection(
          category.name,
          tasks.where((task) => task.categoryId == category.id).toList(),
          categoryId: category.id,
        ),
  ];
  if (filter == null) {
    return sections
        .where((section) =>
            section.tasks.isNotEmpty ||
            section.label != uncategorizedWeeklyLabel)
        .toList();
  }
  return sections;
}

Widget _categoryChip({
  required String label,
  required bool selected,
  required VoidCallback onSelected,
}) =>
    ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
