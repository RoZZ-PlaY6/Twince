import 'dart:ui';

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
import 'plan_screen.dart';

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
          extendBody: true,
          backgroundColor: const Color(0xFF030A19),
          appBar: PreferredSize(
            preferredSize: Size.fromHeight(_destination == 0 ? 112 : 64),
            child: _glassTopBar(context),
          ),
          body: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: Color(0xFF030A19)),
              const IgnorePointer(
                  child: CustomPaint(painter: _NeonWavePainter())),
              Consumer<StorageService>(
                builder: (context, storage, _) {
                  final tasks = storage.getAllTasks();
                  if (_destination == 2) return const PlanScreen();
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
            ],
          ),
          floatingActionButton: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                colors: [AppTheme.cyan, AppTheme.blue, AppTheme.purple],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.cyan.withValues(alpha: 0.35),
                  blurRadius: 20,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: AppTheme.purple.withValues(alpha: 0.3),
                  blurRadius: 26,
                  offset: const Offset(6, 4),
                ),
              ],
            ),
            child: FloatingActionButton.extended(
              elevation: 0,
              backgroundColor: Colors.transparent,
              onPressed: () => _destination == 2
                  ? showAddPlanFlow(context)
                  : showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      showDragHandle: true,
                      builder: (_) => AddTaskBottomSheet(
                        storage: context.read<StorageService>(),
                        initialAlarmEnabled: _destination == 1,
                      ),
                    ),
              icon: const Icon(Icons.add_rounded),
              label: Text(
                _destination == 2 ? 'Add Plan' : 'Add task',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          bottomNavigationBar: _glassBottomNavigation(),
        ),
      );

  Widget _glassTopBar(BuildContext context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF030A19),
              border: Border(
                bottom: BorderSide(
                  color: AppTheme.cyan.withValues(alpha: 0.65),
                  width: 1.2,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.cyan.withValues(alpha: 0.2),
                  blurRadius: 18,
                ),
                BoxShadow(
                  color: AppTheme.purple.withValues(alpha: 0.25),
                  blurRadius: 24,
                  offset: const Offset(12, 5),
                ),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  SizedBox(
                    height: 58,
                    child: Row(
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(left: 18),
                          child: Text(
                            'TWINCE',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.4,
                              color: AppTheme.cyan,
                              fontSize: 17,
                            ),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Analytics',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.insights_outlined,
                              color: AppTheme.cyan),
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                                builder: (_) => const AnalyticsScreen()),
                          ),
                        ),
                        const ExportBackupButton(),
                        IconButton(
                          tooltip: 'History',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.history, color: AppTheme.cyan),
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                                builder: (_) => const HistoryScreen()),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Test notification',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.notifications_outlined,
                              color: AppTheme.cyan),
                          onPressed: () => showDialog<void>(
                            context: context,
                            builder: (_) => TestNotificationDialog(
                                onSend: _sendTestNotification),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                    ),
                  ),
                  if (_destination == 0)
                    Expanded(
                      child: TabBar(
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicatorPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 4),
                        indicator: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.blue.withValues(alpha: 0.05),
                              AppTheme.purple.withValues(alpha: 0.2),
                            ],
                          ),
                          border: Border(
                            bottom: BorderSide(
                              color: AppTheme.purple.withValues(alpha: 0.95),
                              width: 3,
                            ),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.purple.withValues(alpha: 0.45),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.white70,
                        tabs: const [
                          Tab(text: 'Active'),
                          Tab(text: 'Completed'),
                          Tab(text: 'Failed'),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _glassBottomNavigation() => SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(4, 0, 4, 4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              height: 70,
              decoration: BoxDecoration(
                color: const Color(0xDE0A162D),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: AppTheme.cyan.withValues(alpha: 0.62),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.cyan.withValues(alpha: 0.18),
                    blurRadius: 18,
                  ),
                ],
              ),
              child: Row(
                children: [
                  _bottomItem(
                    index: 0,
                    label: 'Tasks',
                    icon: Icons.task_alt_outlined,
                    selectedIcon: Icons.task_alt_rounded,
                  ),
                  _bottomItem(
                    index: 1,
                    label: 'Alarmed Tasks',
                    icon: Icons.alarm_outlined,
                    selectedIcon: Icons.alarm_rounded,
                  ),
                  _bottomItem(
                    index: 2,
                    label: 'Plan',
                    icon: Icons.event_note_outlined,
                    selectedIcon: Icons.event_note_rounded,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _bottomItem({
    required int index,
    required String label,
    required IconData icon,
    required IconData selectedIcon,
  }) {
    final selected = _destination == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _destination = index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: selected
                    ? LinearGradient(
                        colors: [
                          AppTheme.blue.withValues(alpha: 0.22),
                          AppTheme.purple.withValues(alpha: 0.38),
                        ],
                      )
                    : null,
                border: selected
                    ? Border.all(color: AppTheme.purple.withValues(alpha: 0.5))
                    : null,
              ),
              child: Icon(
                selected ? selectedIcon : icon,
                size: 20,
                color: selected ? Colors.white : Colors.white70,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white70,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: selected ? 4 : 3,
              height: selected ? 4 : 3,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected
                    ? AppTheme.cyan
                    : Colors.white.withValues(alpha: 0.18),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: AppTheme.cyan.withValues(alpha: 0.7),
                          blurRadius: 7,
                        )
                      ]
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

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
      if (definitionId != null && occurrences != null) {
        if (addedGroups.add(definitionId)) {
          entries.add(_RecurringOccurrences(definitionId, occurrences));
        }
      } else {
        entries.add(task);
      }
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 104),
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
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: const Color(0xB5102139),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: accent.withValues(alpha: 0.9),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.28),
                blurRadius: 16,
              ),
              BoxShadow(
                color: AppTheme.purple.withValues(alpha: 0.15),
                blurRadius: 26,
                offset: const Offset(10, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: ExpansionTile(
            key: PageStorageKey(
                'recurring-${status.name}-${group.definitionId}'),
            leading: Icon(Icons.repeat_rounded, color: accent),
            iconColor: accent,
            collapsedIconColor: accent,
            shape: const Border(),
            collapsedShape: const Border(),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    definition?.title ?? group.occurrences.first.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (definition != null)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: accent,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    label: const Text('Edit all'),
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      showDragHandle: true,
                      builder: (_) => AddTaskBottomSheet(
                        storage: storage,
                        task: group.occurrences.first,
                        editAll: true,
                      ),
                    ),
                  ),
                PopupMenuButton<String>(
                  tooltip: 'Recurring task actions',
                  icon: const Icon(Icons.more_vert_rounded, size: 20),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'deleteAll',
                      child: Row(children: [
                        Icon(Icons.delete_outline_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Delete all'),
                      ]),
                    ),
                  ],
                  onSelected: (_) => _confirmDeleteRecurring(
                      context, storage, group.definitionId),
                ),
              ],
            ),
            subtitle: Text(
              [if (weekdays.isNotEmpty) weekdays, '$count $statusLabel']
                  .join('  ·  '),
              style: const TextStyle(color: Colors.white70, fontSize: 11),
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

  Future<void> _confirmDeleteRecurring(
      BuildContext context, StorageService storage, String id) async {
    final confirmed = await confirmDeleteAllOccurrences(context);
    if (confirmed == true && context.mounted) {
      await _perform(context, storage.deleteRecurringTask(id));
    }
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

@visibleForTesting
Future<bool> confirmDeleteAllOccurrences(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete recurring task?'),
      content: const Text(
          'All occurrences of this recurring task, including completed and failed ones, will be deleted.'),
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

class _RecurringOccurrences {
  const _RecurringOccurrences(this.definitionId, this.occurrences);

  final String definitionId;
  final List<Task> occurrences;
}

class _NeonWavePainter extends CustomPainter {
  const _NeonWavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final ambient = Paint()
      ..shader = RadialGradient(
        colors: [
          AppTheme.blue.withValues(alpha: 0.13),
          AppTheme.purple.withValues(alpha: 0.04),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.72, size.height * 0.38),
          radius: size.longestSide * 0.58,
        ),
      );
    canvas.drawRect(Offset.zero & size, ambient);

    void wave({
      required double y,
      required Color color,
      required double bend,
      required double width,
    }) {
      final path = Path()
        ..moveTo(-size.width * 0.08, y)
        ..cubicTo(
          size.width * 0.18,
          y - bend,
          size.width * 0.48,
          y + bend,
          size.width * 1.08,
          y - bend * 0.45,
        );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width * 7
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24)
          ..color = color.withValues(alpha: 0.08),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..color = color.withValues(alpha: 0.65),
      );
    }

    wave(
      y: size.height * 0.2,
      color: AppTheme.cyan,
      bend: size.height * 0.08,
      width: 0.7,
    );
  }

  @override
  bool shouldRepaint(covariant _NeonWavePainter oldDelegate) => false;
}
