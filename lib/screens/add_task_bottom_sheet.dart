import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/task.dart';
import '../models/recurring_task.dart';
import '../services/storage_service.dart';
import '../services/alarm_service.dart';
import '../theme/app_theme.dart';
import '../widgets/alarm_sound_picker.dart';
import '../widgets/precise_time_picker.dart';
import '../widgets/sound_picker_field.dart';

class AddTaskBottomSheet extends StatefulWidget {
  const AddTaskBottomSheet({
    super.key,
    required this.storage,
    this.task,
    this.initialAlarmEnabled = false,
  });
  final StorageService storage;
  final Task? task;
  final bool initialAlarmEnabled;

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
  DateTime _start = DateTime.now();
  DateTime _end = DateTime.now().add(const Duration(hours: 1));
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

  // Track if we're editing a recurring task (not just an occurrence)
  RecurringTask? _editingRecurringTask;

  bool get _retrying => widget.task?.status == TaskStatus.failed;

  @override
  void initState() {
    super.initState();
    _isAlarm = widget.initialAlarmEnabled;
    final task = widget.task;
    if (task == null) return;
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

    // If this task was generated from a recurring definition, load the series.
    if (task.recurringDefinitionId != null) {
      _loadRecurringDefinition(task.recurringDefinitionId!);
    }
  }

  Future<void> _loadRecurringDefinition(String recurringId) async {
    try {
      final recurringTask = widget.storage.getRecurringTaskById(recurringId);
      if (recurringTask != null && mounted) {
        setState(() {
          _editingRecurringTask = recurringTask;
          _recurring = true;
          _weekdays
            ..clear()
            ..addAll(recurringTask.weekdays);
        });
      }
    } catch (error) {
      debugPrint('Could not load recurring definition: $error');
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

  String _formatTime(DateTime value) => DateFormat('HH:mm:ss').format(value);

  String get _buttonText {
    if (_saving) return 'Saving…';
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
          'Notification Timer Messages',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Select when to receive notifications during the task timer.',
          style: TextStyle(color: Colors.white54, fontSize: 12),
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
              selectedColor: AppTheme.cyan.withOpacity(0.3),
              checkmarkColor: AppTheme.cyan,
              backgroundColor: isAvailable
                  ? AppTheme.surface
                  : AppTheme.surface.withOpacity(0.5),
              labelStyle: TextStyle(
                color: isAvailable ? Colors.white : Colors.white38,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
              side: BorderSide(
                color: isAvailable
                    ? (isSelected
                        ? AppTheme.cyan
                        : AppTheme.purple.withOpacity(0.5))
                    : Colors.white24,
              ),
            );
          }).toList(),
        ),
        if (!_notificationTimerOptions.isEmpty) ...[
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
    if (!_effectiveEnd().isAfter(_at(_start))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time.')),
      );
      return;
    }
    if (_retrying && !_at(_start).isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a future start time to retry.')),
      );
      return;
    }
    if (widget.task != null && !_effectiveEnd().isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a future end time.')),
      );
      return;
    }
    if (_isAlarm && !_at(_start).isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alarm time must be in the future.')),
      );
      return;
    }
    if (_isAlarm && !await AlarmService.instance.canScheduleExactAlarms()) {
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
      final date = DateTime(_date.year, _date.month, _date.day);
      final existing = widget.task;
      final start = _at(_start);
      final end = _effectiveEnd();
      final customMessage = _customMessageController.text.trim().isEmpty
          ? null
          : _customMessageController.text.trim();
      if (existing == null) {
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
            startTime: _start,
            endTime: _end,
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
            startTime: _start,
            endTime: _end,
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
          await widget.storage.updateRecurringTask(updatedRecurring);
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

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          18,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: SafeArea(
          child: Form(
            key: _form,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _retrying
                        ? 'Retry / Reschedule'
                        : widget.task == null
                            ? 'New task'
                            : 'Edit task',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _title,
                    decoration: const InputDecoration(labelText: 'Title'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Title is required'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _description,
                    decoration: const InputDecoration(labelText: 'Description'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<TaskCategory>(
                    segments: TaskCategory.values
                        .map(
                          (cat) => ButtonSegment<TaskCategory>(
                            value: cat,
                            label: Text(cat.label),
                            icon: Icon(
                              switch (cat) {
                                TaskCategory.daily => Icons.today,
                                TaskCategory.important => Icons.priority_high,
                                TaskCategory.etc => Icons.more_horiz,
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
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Recurring task'),
                    subtitle: const Text('Repeat on selected weekdays'),
                    value: _recurring,
                    onChanged: _retrying
                        ? null
                        : (value) => setState(() {
                              _recurring = value;
                              if (value && _weekdays.isEmpty) {
                                _weekdays.add(DateTime.now().weekday);
                              }
                            }),
                  ),
                  if (_recurring) ...[
                    const Text('Days of the week'),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 7,
                      runSpacing: 3,
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
                  ],
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text('Date: ${DateFormat.yMMMd().format(_date)}'),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setState(() => _date = picked);
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final picked = await showPreciseTimePicker(
                              context: context,
                              initialTime: _start,
                              label: 'Start time',
                            );
                            if (picked != null) {
                              setState(() => _start = picked);
                            }
                          },
                          child: Text('Start ${_formatTime(_start)}'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final picked = await showPreciseTimePicker(
                              context: context,
                              initialTime: _end,
                              label: 'End time',
                            );
                            if (picked != null) setState(() => _end = picked);
                          },
                          child: Text('End ${_formatTime(_end)}'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Alarm'),
                    subtitle: Text(
                      _isAlarm
                          ? 'Rings exactly at the task start time'
                          : 'No full-screen alarm',
                    ),
                    secondary: const Icon(Icons.alarm, color: AppTheme.cyan),
                    value: _isAlarm,
                    onChanged: (value) => setState(() => _isAlarm = value),
                  ),
                  if (_isAlarm) ...[
                    const SizedBox(height: 8),
                    AlarmSoundPicker(
                      type: _alarmSoundType,
                      soundId: _alarmSoundId,
                      soundUri: _alarmSoundUri,
                      onChanged: (type, id, uri) => setState(() {
                        _alarmSoundType = type;
                        _alarmSoundId = id;
                        _alarmSoundUri = uri;
                      }),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _intervalController,
                    decoration: const InputDecoration(
                      labelText: 'Reminder interval (minutes)',
                      hintText: 'e.g. 30',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _customMessageController,
                    decoration: const InputDecoration(
                      labelText: 'Custom notification message',
                      hintText: 'Optional: enter a custom reminder message',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                  const SizedBox(height: 16),
                  _buildNotificationTimerOptions(),
                  const SizedBox(height: 16),
                  SoundPickerField(
                    label: 'Notification Sound',
                    selectedSoundId: _notificationSoundId,
                    customSystemSoundUri: _customSystemSoundUri,
                    hintText: 'Select a notification sound',
                    onChanged: (value) =>
                        setState(() => _notificationSoundId = value),
                    onPickSystemSound: _pickSystemSound,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_buttonText),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
