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

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
            bottom: const TabBar(
              tabs: [
                Tab(text: 'Active'),
                Tab(text: 'Completed'),
                Tab(text: 'Failed'),
              ],
            ),
          ),
          body: Consumer<StorageService>(
            builder: (context, storage, _) {
              final tasks = storage.getAllTasks();
              return TabBarView(
                children: [
                  _taskList(context, storage, tasks, TaskStatus.pending),
                  _taskList(context, storage, tasks, TaskStatus.completed),
                  _taskList(context, storage, tasks, TaskStatus.failed),
                ],
              );
            },
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              showDragHandle: true,
              builder: (_) =>
                  AddTaskBottomSheet(storage: context.read<StorageService>()),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Add task'),
          ),
        ),
      );

  Widget _taskList(
    BuildContext context,
    StorageService storage,
    List<Task> tasks,
    TaskStatus status,
  ) {
    final filtered = tasks.where((task) => task.status == status).toList();
    if (filtered.isEmpty) {
      return Center(
        child: Text(
          status == TaskStatus.pending
              ? 'No active tasks yet'
              : status == TaskStatus.completed
                  ? 'Nothing completed yet'
                  : 'No failed tasks',
          style: const TextStyle(color: Colors.white54),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 90),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final task = filtered[index];
        return TaskCard(
          key: ValueKey(task.id),
          task: task,
          onToggle: () =>
              _perform(context, storage.toggleTaskCompleted(task.id)),
          onDelete: () => _perform(context, storage.deleteTask(task.id)),
          onExpire: () => _perform(context, storage.markTaskFailed(task.id)),
          onEdit: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            showDragHandle: true,
            builder: (_) => AddTaskBottomSheet(storage: storage, task: task),
          ),
        );
      },
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
