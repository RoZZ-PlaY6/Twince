import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/task.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

/// Read-only archive of stored task instances, including legacy records.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  DateTime? _selectedDate;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('History')),
        body: Consumer<StorageService>(builder: (context, storage, _) {
          final tasks = storage.getAllTasks().where((task) {
            final date = _selectedDate;
            return date == null ||
                (task.targetDate.year == date.year &&
                    task.targetDate.month == date.month &&
                    task.targetDate.day == date.day);
          }).toList()
            ..sort((a, b) => b.startTime.compareTo(a.startTime));
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(children: [
                Expanded(
                    child: OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_month, color: AppTheme.cyan),
                  label: Text(_selectedDate == null
                      ? 'All dates'
                      : DateFormat.yMMMMd().format(_selectedDate!)),
                )),
                if (_selectedDate != null)
                  IconButton(
                    tooltip: 'Clear date filter',
                    onPressed: () => setState(() => _selectedDate = null),
                    icon: const Icon(Icons.clear, color: AppTheme.cyan),
                  ),
              ]),
            ),
            Expanded(
                child: tasks.isEmpty
                    ? const Center(
                        child: Text('No tasks for this date.',
                            style: TextStyle(color: Colors.white54)))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: tasks.length,
                        itemBuilder: (context, index) =>
                            _HistoryTile(task: tasks[index]),
                      )),
          ]);
        }),
      );
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.task});
  final Task task;

  @override
  Widget build(BuildContext context) {
    final status = task.status;
    final color = switch (status) {
      TaskStatus.completed => AppTheme.completed,
      TaskStatus.failed => AppTheme.failed,
      TaskStatus.pending => AppTheme.cyan,
    };
    final label = switch (status) {
      TaskStatus.completed => 'Completed',
      TaskStatus.failed => 'Failed',
      TaskStatus.pending => 'Pending',
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.neonCard(accent: color),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text(task.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        decoration: status == TaskStatus.failed
                            ? TextDecoration.lineThrough
                            : null,
                      ))),
          Text(label,
              style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ]),
        if (task.description.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(task.description, style: const TextStyle(color: Colors.white70)),
        ],
        const SizedBox(height: 8),
        Text(
            '${DateFormat.yMMMd().format(task.targetDate)}  ·  ${task.category}',
            style: const TextStyle(color: Colors.white60)),
        if (task.isTimeBound)
          Text(
            '${DateFormat('HH:mm:ss').format(task.startTime)} – ${DateFormat('HH:mm:ss').format(task.endTime)}',
            style: const TextStyle(color: AppTheme.cyan),
          ),
      ]),
    );
  }
}
