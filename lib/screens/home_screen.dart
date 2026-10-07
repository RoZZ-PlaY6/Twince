import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/task.dart';
import '../services/browser_notification.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/task_card.dart';
import '../widgets/test_notification_dialog.dart';
import '../widgets/export_backup_button.dart';
import 'add_task_bottom_sheet.dart';
import 'analytics_screen.dart';
import 'history_screen.dart';

@visibleForTesting
List<Task> activeAlarmedTasks(List<Task> tasks, {DateTime? now}) {
  final current = now ?? DateTime.now();
  return tasks
      .where((task) =>
          task.status == TaskStatus.pending &&
          task.isAlarm &&
          task.endTime.isAfter(current))
      .toList();
}

@visibleForTesting
List<Task> standardTasksByStatus(List<Task> tasks, TaskStatus status) =>
    tasks.where((task) => task.status == status && !task.isAlarm).toList();

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _destination = 0;

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: const Text(
              'TWINCE',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
                color: AppTheme.cyan,
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'Analytics',
                icon: const Icon(Icons.insights_outlined, color: AppTheme.cyan),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) => const AnalyticsScreen()),
                ),
              ),
              const ExportBackupButton(),
              IconButton(
                tooltip: 'History',
                icon: const Icon(Icons.history, color: AppTheme.cyan),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) => const HistoryScreen()),
                ),
              ),
              IconButton(
                tooltip: 'Test notification',
                icon: const Icon(Icons.notifications_outlined,
                    color: AppTheme.cyan),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) =>
                      TestNotificationDialog(onSend: _sendTestNotification),
                ),
              ),
            ],
            bottom: _destination == 0
                ? const TabBar(
                    tabs: [
                      Tab(text: 'Active'),
                      Tab(text: 'Completed'),
                      Tab(text: 'Failed'),
                    ],
                  )
                : null,
          ),
          body: Consumer<StorageService>(
            builder: (context, storage, _) {
              final tasks = storage.getAllTasks();
              if (_destination == 1) {
                return _taskList(
                  context,
                  storage,
                  tasks,
                  TaskStatus.pending,
                  alarmOnly: true,
                );
              }
              return TabBarView(children: [
                _taskList(context, storage, tasks, TaskStatus.pending),
                _taskList(context, storage, tasks, TaskStatus.completed),
                _taskList(context, storage, tasks, TaskStatus.failed),
              ]);
            },
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              showDragHandle: true,
              builder: (_) => AddTaskBottomSheet(
                storage: context.read<StorageService>(),
                initialAlarmEnabled: _destination == 1,
              ),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Add task'),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _destination,
            onDestinationSelected: (index) =>
                setState(() => _destination = index),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.task_alt_outlined),
                selectedIcon: Icon(Icons.task_alt),
                label: 'Tasks',
              ),
              NavigationDestination(
                icon: Icon(Icons.alarm_outlined),
                selectedIcon: Icon(Icons.alarm),
                label: 'Alarmed Tasks',
              ),
            ],
          ),
        ),
      );

  Widget _taskList(BuildContext context, StorageService storage,
      List<Task> tasks, TaskStatus status,
      {bool alarmOnly = false}) {
    final filtered = alarmOnly
        ? activeAlarmedTasks(tasks)
        : standardTasksByStatus(tasks, status);
    if (filtered.isEmpty) {
      return Center(
        child: Text(
          alarmOnly
              ? 'No active alarmed tasks'
              : status == TaskStatus.pending
                  ? 'No active tasks yet'
                  : status == TaskStatus.completed
                      ? 'Nothing completed yet'
                      : 'No failed tasks',
          style: const TextStyle(color: Colors.white54),
        ),
      );
    }

    // Keep Hive occurrences independent; group only their presentation here.
    final occurrencesByDefinition = <String, List<Task>>{};
    for (final task in filtered) {
      final definitionId = task.recurringDefinitionId;
      if (definitionId != null) {
        occurrencesByDefinition.putIfAbsent(definitionId, () => []).add(task);
      }
    }
    final entries = <Object>[];
    final addedGroups = <String>{};
    for (final task in filtered) {
      final definitionId = task.recurringDefinitionId;
      final occurrences = occurrencesByDefinition[definitionId];
      final hasMultipleDays = definitionId != null &&
          (storage.getRecurringTaskById(definitionId)?.weekdays.length ?? 0) >
              1;
      if (definitionId != null &&
          occurrences != null &&
          (hasMultipleDays || occurrences.length > 1)) {
        if (addedGroups.add(definitionId)) {
          entries.add(_RecurringOccurrences(definitionId, occurrences));
        }
      } else {
        entries.add(task);
      }
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 90),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        if (entry is Task) return _taskCard(context, storage, entry);
        final group = entry as _RecurringOccurrences;
        final definition = storage.getRecurringTaskById(group.definitionId);
        const weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final weekdays = definition?.weekdays
                .map((day) => weekdayNames[day - 1])
                .join(' · ') ??
            '';
        final count = group.occurrences.length;
        final statusLabel = switch (status) {
          TaskStatus.pending => 'active',
          TaskStatus.completed => 'completed',
          TaskStatus.failed => 'failed',
        };
        final accent = switch (status) {
          TaskStatus.pending => AppTheme.cyan,
          TaskStatus.completed => AppTheme.completed,
          TaskStatus.failed => AppTheme.failed,
        };
        return Container(
          key: ValueKey('recurring-${status.name}-${group.definitionId}'),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: AppTheme.neonCard(accent: accent),
          clipBehavior: Clip.antiAlias,
          child: ExpansionTile(
            key: PageStorageKey(
                'recurring-${status.name}-${group.definitionId}'),
            leading: Icon(Icons.repeat, color: accent),
            iconColor: accent,
            collapsedIconColor: accent,
            shape: const Border(),
            collapsedShape: const Border(),
            title: Text(definition?.title ?? group.occurrences.first.title),
            subtitle: Text(
              [if (weekdays.isNotEmpty) weekdays, '$count $statusLabel']
                  .join('  ·  '),
              style: const TextStyle(color: Colors.white70),
            ),
            childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            children: [
              for (final occurrence in group.occurrences) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 6),
                    child: Text(
                      MaterialLocalizations.of(context)
                          .formatMediumDate(occurrence.targetDate),
                      style: TextStyle(color: accent),
                    ),
                  ),
                ),
                _taskCard(context, storage, occurrence),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _taskCard(BuildContext context, StorageService storage, Task task) {
    return TaskCard(
      key: ValueKey(task.id),
      task: task,
      onToggle: () => _perform(context, storage.toggleTaskCompleted(task.id)),
      onDelete: () => _perform(context, storage.deleteTask(task.id)),
      onExpire: () => _perform(context, storage.markTaskFailed(task.id)),
      onEdit: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => AddTaskBottomSheet(storage: storage, task: task),
      ),
    );
  }

  Future<bool> _sendTestNotification(String title, String body) async {
    if (kIsWeb) return showBrowserNotification(title, body);
    return NotificationService.instance.showTest(title, body);
  }

  Future<void> _perform(BuildContext context, Future<void> action) async {
    try {
      await action;
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Task action failed: $error')));
      }
    }
  }
}

class _RecurringOccurrences {
  const _RecurringOccurrences(this.definitionId, this.occurrences);

  final String definitionId;
  final List<Task> occurrences;
}
