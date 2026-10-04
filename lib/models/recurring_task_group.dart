import 'package:flutter/material.dart';
import 'task.dart';

/// Represents a group of recurring task occurrences sharing the same definition.
class RecurringTaskGroup {
  const RecurringTaskGroup({
    required this.recurringDefinitionId,
    required this.title,
    required this.description,
    required this.category,
    required this.weekdays,
    required this.startTime,
    required this.endTime,
    required this.reminderIntervalMinutes,
    required this.categoryColor,
    required this.categoryIcon,
    required this.occurrences,
    required this.notificationTimerOptions,
    required this.notificationSoundId,
    this.customNotificationMessage,
    this.customSystemSoundUri,
  });

  /// The recurring definition ID that all occurrences share
  final String recurringDefinitionId;

  /// The task title
  final String title;

  /// Optional description
  final String description;

  /// Task category
  final dynamic category;

  /// Weekdays for recurrence (1-7)
  final List<int> weekdays;

  /// Start time
  final DateTime startTime;

  /// End time
  final DateTime endTime;

  /// Reminder interval in minutes
  final int reminderIntervalMinutes;

  /// Category color for display
  final Color categoryColor;

  /// Category icon for display
  final IconData categoryIcon;

  /// All occurrences in this group
  final List<Task> occurrences;

  /// Notification timer options
  final Set<dynamic> notificationTimerOptions;

  /// Notification sound ID
  final String notificationSoundId;

  /// Optional custom notification message
  final String? customNotificationMessage;

  /// Custom system sound URI
  final String? customSystemSoundUri;

  /// Total number of occurrences
  int get totalOccurrences => occurrences.length;

  /// Number of completed occurrences
  int get completedCount => occurrences.where((t) => t.status.index == 2).length;

  /// Number of pending occurrences
  int get pendingCount => occurrences.where((t) => t.status.index == 1).length;

  /// Number of failed occurrences
  int get failedCount => occurrences.where((t) => t.status.index == 3).length;

  /// Whether all occurrences are completed
  bool get isFullyCompleted => occurrences.isNotEmpty && 
      occurrences.every((t) => t.status.index == 2);

  /// Whether all occurrences are failed
  bool get allFailed => occurrences.isNotEmpty && 
      occurrences.every((t) => t.status.index == 3);

  /// Whether any occurrence is currently active
  bool get hasActiveOccurrence {
    return occurrences.any((t) => 
      t.status.index == 1 && // pending
      t.isTimeBound &&
      !DateTime.now().isBefore(t.startTime) &&
      DateTime.now().isBefore(t.endTime));
  }

  /// Whether any occurrence is currently active and in progress
  bool get hasActiveInProgress {
    final now = DateTime.now();
    return occurrences.any((t) => 
      t.status.index == 1 && // pending
      t.isTimeBound &&
      !now.isBefore(t.startTime) &&
      now.isBefore(t.endTime));
  }

  /// Get the next upcoming occurrence
  Task? get nextOccurrence {
    final now = DateTime.now();
    final futureOccurrences = occurrences
        .where((t) => t.startTime.isAfter(DateTime.now()))
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    return futureOccurrences.isNotEmpty ? futureOccurrences.first : null;
  }

  /// Get the next upcoming occurrence date
  DateTime? get nextOccurrenceDate {
    return nextOccurrence?.startTime;
  }

  /// Get all unique weekdays as localized strings
  List<String> get weekdayLabels {
    const weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return weekdays.map((d) => weekdayNames[d - 1]).toList();
  }

  /// Get the recurring task group ID for use as a key
  String get groupKey => recurringDefinitionId;
}