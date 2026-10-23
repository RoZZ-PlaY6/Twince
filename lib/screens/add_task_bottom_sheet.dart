import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/task.dart';
import '../models/recurring_task.dart';
import '../services/storage_service.dart';
import '../services/alarm_service.dart';
import '../services/user_preferences_service.dart';
import '../theme/app_theme.dart';
import '../widgets/alarm_sound_picker.dart';
import '../widgets/precise_time_picker.dart';
import '../widgets/sound_picker_field.dart';

typedef ResolvedTaskSchedule = ({
  DateTime targetDate,
  DateTime startTime,
  DateTime endTime,
});

/// Combines clock-only selections with the task's calendar date in local time.
///
/// A completed window scheduled for today rolls to tomorrow. The end-time
/// comparison includes a short grace period for picker/save latency.
@visibleForTesting
ResolvedTaskSchedule resolveTaskSchedule({
  required DateTime selectedDate,
  required DateTime selectedStartTime,
  required DateTime selectedEndTime,
  required DateTime now,
  required bool adjustPassedAlarm,
  Duration alarmGracePeriod = const Duration(seconds: 30),
}) {
  final localNow = now.toLocal();
  var taskDay =
      DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
  final today = DateTime(localNow.year, localNow.month, localNow.day);
  if (adjustPassedAlarm && taskDay.isBefore(today)) taskDay = today;

  DateTime combine(DateTime day, DateTime clock) => DateTime(
        day.year,
        day.month,
        day.day,
        clock.hour,
        clock.minute,
        clock.second,
      );

  var start = combine(taskDay, selectedStartTime);
  var end = combine(taskDay, selectedEndTime);
  if (!end.isAfter(start)) end = end.add(const Duration(days: 1));
  if (adjustPassedAlarm &&
      taskDay == today &&
      end.isBefore(localNow.subtract(alarmGracePeriod))) {
    taskDay = taskDay.add(const Duration(days: 1));
    start = combine(taskDay, selectedStartTime);
    end = combine(taskDay, selectedEndTime);
    if (!end.isAfter(start)) end = end.add(const Duration(days: 1));
  }

  return (targetDate: taskDay, startTime: start, endTime: end);
}

class AddTaskBottomSheet extends StatefulWidget {
  const AddTaskBottomSheet({
    super.key,
    required this.storage,
    this.task,
    this.editAll = false,
    this.initialAlarmEnabled = false,
    this.templateDate,
    this.onSaveTemplate,
  });
  final StorageService storage;
  final Task? task;
  final bool editAll;
  final bool initialAlarmEnabled;
  final DateTime? templateDate;
  final Future<void> Function(Task task)? onSaveTemplate;

  @override
  State<AddTaskBottomSheet> createState() => _AddTaskBottomSheetState();
}

class _AddTaskBottomSheetState extends State<AddTaskBottomSheet> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _intervalController = TextEditingController(text: '60');
  final _customMessageController = TextEditingController();
  DateTime _date = DateTime.now();
  late DateTime _start;
  late DateTime _end;
  TaskCategory _category = TaskCategory.etc;
  String _notificationSoundId = 'cyber_pulse';
  String? _customSystemSoundUri;
  bool _saving = false;
  bool _recurring = false;
  final Set<int> _weekdays = {};
  Set<NotificationTimerOption> _notificationTimerOptions = {};
  late bool _isAlarm;
  AlarmSoundType _alarmSoundType = AlarmSoundType.system;
  String _alarmSoundId = 'cyber_pulse';
  String? _alarmSoundUri;

  RecurringTask? _editingRecurringTask;

  bool get _retrying =>
      !widget.editAll &&
      widget.onSaveTemplate == null &&
      widget.task?.status == TaskStatus.failed;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _start = DateTime(now.year, now.month, now.day, now.hour, now.minute);
    _end = _start.add(const Duration(hours: 1));
    _isAlarm = widget.initialAlarmEnabled;
    if (widget.templateDate != null) _date = widget.templateDate!;
    final task = widget.task;
    if (task == null) {
      // New task: default the alarm tone to the user's last saved selection.
      final last = UserPreferencesService.instance.getLastAlarmSound();
      if (last != null) {
        _alarmSoundType = last.type;
        _alarmSoundId = last.soundId;
        _alarmSoundUri = last.uri;
      }
      return;
    }
    _title.text = task.title;
    _description.text = task.description;
    _category = task.category;
    _date = task.targetDate;
    _start = task.startTime;
    _end = task.endTime;
    _intervalController.text = task.reminderIntervalMinutes.toString();
    _customMessageController.text =
        task.customNotificationMessage?.trim() ?? '';
    _notificationSoundId = task.notificationSoundId;
    _customSystemSoundUri = task.customSystemSoundUri;
    _notificationTimerOptions = task.notificationTimerOptions;
    _isAlarm = task.isAlarm;
    _alarmSoundType = task.alarmSoundType;
    _alarmSoundId = task.alarmSoundId;
    _alarmSoundUri = task.alarmSoundUri;

    if (widget.editAll && task.recurringDefinitionId != null) {
      final definition =
          widget.storage.getRecurringTaskById(task.recurringDefinitionId!);
      if (definition != null) {
        _editingRecurringTask = definition;
        _recurring = true;
        _title.text = definition.title;
        _description.text = definition.description;
        _category = definition.category;
        _date = definition.firstDate;
        _start = definition.startTime;
        _end = definition.endTime;
        _intervalController.text =
            definition.reminderIntervalMinutes.toString();
        _customMessageController.text =
            definition.customNotificationMessage ?? '';
        _notificationSoundId = definition.notificationSoundId;
        _customSystemSoundUri = definition.customSystemSoundUri;
        _notificationTimerOptions = definition.notificationTimerOptions;
        _isAlarm = definition.isAlarm;
        _alarmSoundType = definition.alarmSoundType;
        _alarmSoundId = definition.alarmSoundId;
        _alarmSoundUri = definition.alarmSoundUri;
        _weekdays.addAll(definition.weekdays);
      }
    }
  }

  DateTime _at(DateTime time) => DateTime(
        _date.year,
        _date.month,
        _date.day,
        time.hour,
        time.minute,
        time.second,
      );

  DateTime _effectiveEnd() {
    final end = _at(_end);
    final start = _at(_start);
    return end.isAfter(start) ? end : end.add(const Duration(days: 1));
  }

  String _formatTime(DateTime value) => DateFormat('HH:mm').format(value);

  Future<void> _rememberAlarmTone() =>
      UserPreferencesService.instance.saveLastAlarmSound(SavedAlarmPreference(
        type: _alarmSoundType,
        soundId: _alarmSoundId,
        uri: _alarmSoundUri,
      ));

  String get _buttonText {
    if (_saving) return 'Saving…';
    if (widget.onSaveTemplate != null) {
      return widget.task == null ? 'Add to plan' : 'Save plan task';
    }
    if (_retrying) return 'Retry task';
    if (widget.task == null) {
      return _recurring ? 'Create recurring task' : 'Create task';
    }
    if (_editingRecurringTask != null) return 'Update recurring task';
    if (_recurring) return 'Update recurring task';
    return 'Save changes';
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _intervalController.dispose();
    _customMessageController.dispose();
    super.dispose();
  }

  Widget _buildNotificationTimerOptions() {
    final options = NotificationTimerOption.values;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Repeat interval',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Choose when reminders should appear during the task.',
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final isAvailable = option.isAvailableForDuration(
                _effectiveEnd().difference(_at(_start)));
            final isSelected = _notificationTimerOptions.contains(option);

            return FilterChip(
              key: ValueKey('timer-option-${option.name}'),
              label: Text(option.label),
              selected: isSelected && isAvailable,
              onSelected: isAvailable
                  ? (selected) {
                      setState(() {
                        if (selected) {
                          _notificationTimerOptions.add(option);
                        } else {
                          _notificationTimerOptions.remove(option);
                        }
                      });
                    }
                  : null,
              tooltip: option.description,
              showCheckmark: true,
              selectedColor: AppTheme.purple.withValues(alpha: 0.45),
              checkmarkColor: Colors.white,
              backgroundColor: isAvailable
                  ? const Color(0xA8182A50)
                  : const Color(0x66182A50),
              labelStyle: TextStyle(
                color: isAvailable ? Colors.white : Colors.white38,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
              side: BorderSide(
                color: isAvailable
                    ? (isSelected
                        ? AppTheme.cyan
                        : AppTheme.cyan.withValues(alpha: 0.32))
                    : Colors.white24,
              ),
            );
          }).toList(),
        ),
        if (_notificationTimerOptions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Selected: ${_notificationTimerOptions.map((o) => o.label).join(', ')}',
            style: TextStyle(
                color: AppTheme.cyan,
                fontSize: 12,
                fontWeight: FontWeight.w500),
          ),
        ],
      ],
    );
  }

  Future<void> _pickSystemSound() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('System sound picker not yet implemented')),
    );
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final interval = int.tryParse(_intervalController.text.trim());
    if (interval == null || interval < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Reminder interval must be a positive integer')),
      );
      return;
    }
    final now = DateTime.now().toLocal();
    final schedule = resolveTaskSchedule(
      selectedDate: _date,
      selectedStartTime: _start,
      selectedEndTime: _end,
      now: now,
      adjustPassedAlarm:
          _isAlarm && !widget.editAll && widget.onSaveTemplate == null,
    );
    if (_retrying && !schedule.startTime.isAfter(now)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a future start time to retry.')),
      );
      return;
    }
    if (widget.task != null &&
        widget.onSaveTemplate == null &&
        !widget.editAll &&
        !schedule.endTime.isAfter(now)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a future end time.')),
      );
      return;
    }
    if (_isAlarm &&
        widget.onSaveTemplate == null &&
        !widget.editAll &&
        schedule.endTime.isBefore(now.subtract(const Duration(seconds: 30)))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alarm time must be in the future.')),
      );
      return;
    }
    if (_isAlarm &&
        !kIsWeb &&
        !await AlarmService.instance.canScheduleExactAlarms()) {
      await AlarmService.instance.requestExactAlarmAccess();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Allow exact alarms in Android settings, then tap save again.',
            ),
          ),
        );
      }
      return;
    }
    setState(() => _saving = true);
    try {
      final date = schedule.targetDate;
      final existing = widget.task;
      final start = schedule.startTime;
      final end = schedule.endTime;
      final customMessage = _customMessageController.text.trim().isEmpty
          ? null
          : _customMessageController.text.trim();
      if (widget.onSaveTemplate != null) {
        await widget.onSaveTemplate!(Task(
          id: existing?.id,
          title: _title.text,
          description: _description.text.trim(),
          category: _category,
          targetDate: date,
          startTime: start,
          endTime: end,
          reminderIntervalMinutes: interval,
          createdAt: existing?.createdAt,
          customNotificationMessage: customMessage,
          notificationSoundId: _notificationSoundId,
          customSystemSoundUri: _customSystemSoundUri,
          notificationTimerOptions: _notificationTimerOptions,
          isAlarm: _isAlarm,
          alarmSoundType: _alarmSoundType,
          alarmSoundId: _alarmSoundId,
          alarmSoundUri: _alarmSoundUri,
        ));
      } else if (existing == null) {
        if (_recurring) {
          if (_weekdays.isEmpty) {
            throw ArgumentError('Select at least one weekday');
          }
          await widget.storage.addRecurringTask(RecurringTask(
            title: _title.text,
            description: _description.text.trim(),
            category: _category,
            weekdays: _weekdays.toList(),
            firstDate: date,
            startTime: start,
            endTime: end,
            reminderIntervalMinutes: interval,
            customNotificationMessage: customMessage,
            notificationSoundId: _notificationSoundId,
            customSystemSoundUri: _customSystemSoundUri,
            notificationTimerOptions: _notificationTimerOptions,
            isAlarm: _isAlarm,
            alarmSoundType: _alarmSoundType,
            alarmSoundId: _alarmSoundId,
            alarmSoundUri: _alarmSoundUri,
          ));
        } else {
          await widget.storage.addTask(Task(
            title: _title.text,
            description: _description.text.trim(),
            category: _category,
            targetDate: date,
            startTime: start,
            endTime: end,
            reminderIntervalMinutes: interval,
            customNotificationMessage: customMessage,
            notificationSoundId: _notificationSoundId,
            customSystemSoundUri: _customSystemSoundUri,
            notificationTimerOptions: _notificationTimerOptions,
            isAlarm: _isAlarm,
            alarmSoundType: _alarmSoundType,
            alarmSoundId: _alarmSoundId,
            alarmSoundUri: _alarmSoundUri,
          ));
        }
        if (_isAlarm) await _rememberAlarmTone();
      } else {
        // Check if we're editing a recurring task definition
        if (_editingRecurringTask != null && _recurring) {
          if (_weekdays.isEmpty) {
            throw ArgumentError('Select at least one weekday');
          }
          final updatedRecurring = RecurringTask(
            id: _editingRecurringTask!.id,
            title: _title.text,
            description: _description.text.trim(),
            category: _category,
            weekdays: _weekdays.toList(),
            firstDate: date,
            startTime: start,
            endTime: end,
            reminderIntervalMinutes: interval,
            customNotificationMessage: customMessage,
            notificationSoundId: _notificationSoundId,
            customSystemSoundUri: _customSystemSoundUri,
            notificationTimerOptions: _notificationTimerOptions,
            isAlarm: _isAlarm,
            alarmSoundType: _alarmSoundType,
            alarmSoundId: _alarmSoundId,
            alarmSoundUri: _alarmSoundUri,
            createdAt: _editingRecurringTask!.createdAt,
            generatedThrough: _editingRecurringTask!.generatedThrough,
          );
          await widget.storage.updateRecurringTask(updatedRecurring,
              applyToAllOccurrences: widget.editAll);
        } else {
          final edited = existing.copyWith(
            title: _title.text,
            description: _description.text.trim(),
            category: _category,
            targetDate: date,
            startTime: start,
            endTime: end,
            reminderIntervalMinutes: interval,
            customNotificationMessage: customMessage,
            notificationSoundId: _notificationSoundId,
            customSystemSoundUri: _customSystemSoundUri,
            notificationTimerOptions: _notificationTimerOptions,
            isAlarm: _isAlarm,
            alarmSoundType: _alarmSoundType,
            alarmSoundId: _alarmSoundId,
            alarmSoundUri: _alarmSoundUri,
          );
          if (_retrying) {
            await widget.storage.retryTask(edited);
          } else {
            await widget.storage.updateTask(edited);
          }
        }
      }
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save task: $error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _neonInput(
    String label, {
    String? hint,
    IconData? icon,
  }) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon:
            icon == null ? null : Icon(icon, color: AppTheme.purple, size: 21),
        filled: true,
        fillColor: const Color(0xB5122344),
        labelStyle: const TextStyle(color: Colors.white70),
        hintStyle: const TextStyle(color: Colors.white38),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: AppTheme.blue.withValues(alpha: 0.65),
            width: 1.1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppTheme.cyan, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppTheme.failed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppTheme.failed, width: 1.5),
        ),
      );

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF071126),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0B1A3A), Color(0xFF070D22)],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Form(
                  key: _form,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _GlassPanel(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      AppTheme.cyan,
                                      AppTheme.blue,
                                      AppTheme.purple,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.purple
                                          .withValues(alpha: 0.5),
                                      blurRadius: 18,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  widget.task == null
                                      ? Icons.add_rounded
                                      : Icons.edit_rounded,
                                  color: Colors.white,
                                  size: 30,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _retrying
                                          ? 'Retry Task'
                                          : widget.task == null
                                              ? 'Add Task'
                                              : 'Edit Task',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    const SizedBox(height: 3),
                                    const Text(
                                      'Turn your goals into reality',
                                      style: TextStyle(color: Colors.white54),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton.filled(
                                tooltip: 'Close',
                                onPressed: () => Navigator.of(context).pop(),
                                style: IconButton.styleFrom(
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.08),
                                  foregroundColor: Colors.white70,
                                ),
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _title,
                          decoration: _neonInput(
                            'Task Title',
                            icon: Icons.edit_outlined,
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                                  ? 'Title is required'
                                  : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _description,
                          decoration: _neonInput(
                            'Description (Optional)',
                            icon: Icons.description_outlined,
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 14),
                        SegmentedButton<TaskCategory>(
                          style: ButtonStyle(
                            backgroundColor:
                                WidgetStateProperty.resolveWith((states) {
                              if (states.contains(WidgetState.selected)) {
                                return AppTheme.purple.withValues(alpha: 0.55);
                              }
                              return const Color(0xA814264B);
                            }),
                            foregroundColor:
                                const WidgetStatePropertyAll(Colors.white),
                            side: WidgetStateProperty.resolveWith((states) {
                              final selected =
                                  states.contains(WidgetState.selected);
                              return BorderSide(
                                color: selected
                                    ? AppTheme.cyan
                                    : AppTheme.blue.withValues(alpha: 0.35),
                              );
                            }),
                          ),
                          segments: TaskCategory.values
                              .map(
                                (cat) => ButtonSegment<TaskCategory>(
                                  value: cat,
                                  label: Text(cat.label),
                                  icon: Icon(
                                    switch (cat) {
                                      TaskCategory.daily => Icons.today_rounded,
                                      TaskCategory.important =>
                                        Icons.priority_high_rounded,
                                      TaskCategory.etc =>
                                        Icons.more_horiz_rounded,
                                    },
                                  ),
                                ),
                              )
                              .toList(),
                          selected: {_category},
                          onSelectionChanged: (selection) =>
                              setState(() => _category = selection.first),
                          multiSelectionEnabled: false,
                          showSelectedIcon: false,
                        ),
                        const SizedBox(height: 16),
                        _GlassPanel(
                          child: Column(
                            children: [
                              if (widget.onSaveTemplate == null)
                                SwitchTheme(
                                  data: SwitchTheme.of(context).copyWith(
                                    thumbColor: WidgetStateProperty.resolveWith(
                                        (states) => Colors.white),
                                    trackColor: WidgetStateProperty.resolveWith(
                                      (states) =>
                                          states.contains(WidgetState.selected)
                                              ? AppTheme.purple
                                              : const Color(0xFF26375E),
                                    ),
                                  ),
                                  child: SwitchListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text(
                                      'Recurring task',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700),
                                    ),
                                    subtitle: const Text(
                                      'Repeat on selected weekdays',
                                      style: TextStyle(color: Colors.white54),
                                    ),
                                    value: _recurring,
                                    onChanged: _retrying ||
                                            widget.task
                                                    ?.recurringDefinitionId !=
                                                null
                                        ? null
                                        : (value) => setState(() {
                                              _recurring = value;
                                              if (value && _weekdays.isEmpty) {
                                                _weekdays.add(
                                                    DateTime.now().weekday);
                                              }
                                            }),
                                  ),
                                ),
                              if (_recurring) ...[
                                const Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Days of the week',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Wrap(
                                    spacing: 7,
                                    runSpacing: 7,
                                    children: [
                                      for (var day = 1; day <= 7; day++)
                                        FilterChip(
                                          key: ValueKey('weekday-$day'),
                                          label: Text(const [
                                            'Mon',
                                            'Tue',
                                            'Wed',
                                            'Thu',
                                            'Fri',
                                            'Sat',
                                            'Sun'
                                          ][day - 1]),
                                          selected: _weekdays.contains(day),
                                          selectedColor: AppTheme.purple
                                              .withValues(alpha: 0.52),
                                          side: BorderSide(
                                            color: _weekdays.contains(day)
                                                ? AppTheme.cyan
                                                : AppTheme.blue
                                                    .withValues(alpha: 0.3),
                                          ),
                                          onSelected: _retrying
                                              ? null
                                              : (selected) => setState(() {
                                                    if (selected) {
                                                      _weekdays.add(day);
                                                    } else {
                                                      _weekdays.remove(day);
                                                    }
                                                  }),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              if (widget.onSaveTemplate == null)
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    style: _neonButtonStyle(),
                                    icon: const Icon(
                                        Icons.calendar_month_rounded),
                                    label: Text(
                                      'Date: ${DateFormat.yMMMd().format(_date)}',
                                    ),
                                    onPressed: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: _date,
                                        firstDate: DateTime(2000),
                                        lastDate: DateTime(2100),
                                      );
                                      if (picked != null) {
                                        setState(() => _date = picked);
                                      }
                                    },
                                  ),
                                ),
                              const SizedBox(height: 10),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final startButton = OutlinedButton(
                                    style: _neonButtonStyle(),
                                    onPressed: () async {
                                      final picked =
                                          await showPreciseTimePicker(
                                        context: context,
                                        initialTime: _start,
                                        label: 'Start time',
                                      );
                                      if (picked != null) {
                                        setState(() => _start = picked);
                                      }
                                    },
                                    child: Text('Start ${_formatTime(_start)}'),
                                  );
                                  final endButton = OutlinedButton(
                                    style: _neonButtonStyle(),
                                    onPressed: () async {
                                      final picked =
                                          await showPreciseTimePicker(
                                        context: context,
                                        initialTime: _end,
                                        label: 'End time',
                                      );
                                      if (picked != null) {
                                        setState(() => _end = picked);
                                      }
                                    },
                                    child: Text('End ${_formatTime(_end)}'),
                                  );
                                  if (constraints.maxWidth < 410) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        startButton,
                                        const SizedBox(height: 8),
                                        endButton,
                                      ],
                                    );
                                  }
                                  return Row(
                                    children: [
                                      Expanded(child: startButton),
                                      const SizedBox(width: 10),
                                      Expanded(child: endButton),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _GlassPanel(
                          child: Column(
                            children: [
                              SwitchTheme(
                                data: SwitchTheme.of(context).copyWith(
                                  thumbColor: const WidgetStatePropertyAll(
                                      Colors.white),
                                  trackColor: WidgetStateProperty.resolveWith(
                                    (states) =>
                                        states.contains(WidgetState.selected)
                                            ? AppTheme.cyan
                                            : const Color(0xFF26375E),
                                  ),
                                ),
                                child: SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  secondary: Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: AppTheme.purple
                                          .withValues(alpha: 0.35),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppTheme.purple
                                              .withValues(alpha: 0.45),
                                          blurRadius: 14,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                        Icons.notifications_active_rounded),
                                  ),
                                  title: const Text(
                                    'Smart Alarm & Reminders',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w800),
                                  ),
                                  subtitle: Text(
                                    _isAlarm
                                        ? 'Exact alarm at task end'
                                        : 'Never miss what matters',
                                    style:
                                        const TextStyle(color: Colors.white54),
                                  ),
                                  value: _isAlarm,
                                  onChanged: (value) =>
                                      setState(() => _isAlarm = value),
                                ),
                              ),
                              if (_isAlarm) ...[
                                const SizedBox(height: 10),
                                AlarmSoundPicker(
                                  type: _alarmSoundType,
                                  soundId: _alarmSoundId,
                                  soundUri: _alarmSoundUri,
                                  onChanged: (type, id, uri) {
                                    setState(() {
                                      _alarmSoundType = type;
                                      _alarmSoundId = id;
                                      _alarmSoundUri = uri;
                                    });
                                    _rememberAlarmTone();
                                  },
                                ),
                                const SizedBox(height: 16),
                              ],
                              TextFormField(
                                controller: _intervalController,
                                decoration: _neonInput(
                                  'Reminder interval (minutes)',
                                  hint: 'e.g. 30',
                                  icon: Icons.timer_outlined,
                                ),
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                validator: (value) {
                                  final n = int.tryParse(value ?? '');
                                  return n == null || n < 1
                                      ? 'Enter a positive integer'
                                      : null;
                                },
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _customMessageController,
                                decoration: _neonInput(
                                  'Custom notification message',
                                  hint:
                                      'Optional: enter a custom reminder message',
                                  icon: Icons.message_outlined,
                                ),
                                maxLines: 3,
                                maxLength: 200,
                                validator: (value) {
                                  final trimmed = value?.trim() ?? '';
                                  if (trimmed.length > 200) {
                                    return 'Message must be 200 characters or less';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 4),
                              _buildNotificationTimerOptions(),
                              const SizedBox(height: 16),
                              SoundPickerField(
                                label: 'Notification Sound',
                                selectedSoundId: _notificationSoundId,
                                customSystemSoundUri: _customSystemSoundUri,
                                hintText: 'Select a notification sound',
                                onChanged: (value) => setState(
                                    () => _notificationSoundId = value),
                                onPickSystemSound: _pickSystemSound,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          height: 58,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                AppTheme.purple,
                                AppTheme.blue,
                                AppTheme.cyan,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.purple.withValues(alpha: 0.42),
                                blurRadius: 22,
                              ),
                            ],
                          ),
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            onPressed: _saving ? null : _save,
                            icon: const Icon(Icons.add_rounded),
                            label: Text(
                              _buttonText,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
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
        ),
      );

  ButtonStyle _neonButtonStyle() => OutlinedButton.styleFrom(
        foregroundColor: AppTheme.purple,
        backgroundColor: const Color(0xA814264B),
        side: BorderSide(color: AppTheme.blue.withValues(alpha: 0.65)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      );
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: const Color(0xB20B1B3A),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: AppTheme.blue.withValues(alpha: 0.48),
            width: 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.purple.withValues(alpha: 0.14),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: child,
      );
}
