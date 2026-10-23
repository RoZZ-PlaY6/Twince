import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/task.dart';
import 'alarm_restart.dart';
import 'storage_service.dart';

class AlarmSoundSelection {
  const AlarmSoundSelection({required this.uri, required this.label});

  final String uri;
  final String label;
}

class AlarmService {
  AlarmService._();

  static final AlarmService instance = AlarmService._();
  static const _channel = MethodChannel('twince/alarms');
  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<bool> canScheduleExactAlarms() async {
    if (!_isAndroid) return false;
    return await _channel.invokeMethod<bool>('canScheduleExactAlarms') ?? false;
  }

  Future<bool> requestExactAlarmAccess() async {
    if (!_isAndroid) return false;
    return await _channel.invokeMethod<bool>('requestExactAlarmAccess') ??
        false;
  }

  Future<void> schedule(Task task) async {
    if (!_isAndroid || !task.isAlarm || task.status != TaskStatus.pending) {
      return;
    }
    final triggerTime = task.endTime.toLocal();
    if (!triggerTime.isAfter(DateTime.now().toLocal())) return;
    await _channel.invokeMethod<void>('schedule', {
      'taskId': task.id,
      'title': task.title,
      'description': task.description,
      'triggerAtMillis': triggerTime.millisecondsSinceEpoch,
      'soundType': task.alarmSoundType.name,
      'soundId': task.alarmSoundId,
      'soundUri': task.alarmSoundUri,
      'category': task.category.name,
      'startAtMillis': task.startTime.toLocal().millisecondsSinceEpoch,
      'endAtMillis': task.endTime.toLocal().millisecondsSinceEpoch,
      'reminderIntervalMinutes': task.reminderIntervalMinutes,
      'isTimeBound': task.isTimeBound,
      'notificationSoundId': task.notificationSoundId,
      'customNotificationMessage': task.customNotificationMessage,
      'customSystemSoundUri': task.customSystemSoundUri,
      'notificationTimers':
          task.notificationTimerOptions.map((option) => option.name).join(','),
    });
  }

  /// Creates Restart copies that were requested while Flutter was not running.
  /// This does not change the original task.
  Future<void> consumePendingRestarts(StorageService storage) async {
    if (!_isAndroid) return;
    final pending =
        await _channel.invokeMethod<List<dynamic>>('consumePendingRestarts');
    for (final item in pending ?? const <dynamic>[]) {
      if (item is! Map) continue;
      await storage.addTask(
        buildRestartedAlarmTaskFromMap(item, DateTime.now()),
      );
    }
  }

  void listenForRestarts(StorageService storage) {
    if (!_isAndroid) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'pendingRestarts') {
        await consumePendingRestarts(storage);
      }
    });
  }

  Future<void> cancel(String taskId) async {
    if (!_isAndroid) return;
    await _channel.invokeMethod<void>('cancel', {'taskId': taskId});
  }

  Future<AlarmSoundSelection?> pickSystemSound() async {
    if (!_isAndroid) return null;
    final result =
        await _channel.invokeMapMethod<String, dynamic>('pickSystemSound');
    if (result == null || result['uri'] == null) return null;
    return AlarmSoundSelection(
      uri: result['uri']! as String,
      label: result['label'] as String? ?? 'System alarm',
    );
  }

  Future<AlarmSoundSelection?> pickCustomAudio() async {
    if (!_isAndroid) return null;
    final result =
        await _channel.invokeMapMethod<String, dynamic>('pickCustomAudio');
    if (result == null || result['uri'] == null) return null;
    return AlarmSoundSelection(
      uri: result['uri']! as String,
      label: result['label'] as String? ?? 'Custom audio',
    );
  }
}
