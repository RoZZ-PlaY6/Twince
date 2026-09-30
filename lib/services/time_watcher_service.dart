import 'dart:async';

import 'package:flutter/widgets.dart';

import '../models/task.dart';
import 'storage_service.dart';

/// Rechecks on app resume and every 30 seconds while the app is alive.
class TimeWatcherService with WidgetsBindingObserver {
  TimeWatcherService(this._storage);
  final StorageService _storage;
  Timer? _timer;
  bool _checking = false;

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => check());
    check();
  }

  Future<void> check() async {
    if (_checking) return;
    _checking = true;
    try {
      await _storage.generateRecurringInstances();
      final now = DateTime.now();
      for (final task in _storage.getAllTasks()) {
        if (task.isTimeBound &&
            task.status == TaskStatus.pending &&
            now.isAfter(task.endTime)) {
          await _storage.markTaskFailed(task.id);
        }
      }
    } finally {
      _checking = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) check();
  }

  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }
}
