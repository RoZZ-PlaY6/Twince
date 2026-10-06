import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/task.dart';

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
    if (!task.startTime.isAfter(DateTime.now())) return;
    await _channel.invokeMethod<void>('schedule', {
      'taskId': task.id,
      'title': task.title,
      'description': task.description,
      'triggerAtMillis': task.startTime.millisecondsSinceEpoch,
      'soundType': task.alarmSoundType.name,
      'soundId': task.alarmSoundId,
      'soundUri': task.alarmSoundUri,
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
