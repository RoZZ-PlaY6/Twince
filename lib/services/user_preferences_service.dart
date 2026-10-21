import 'package:shared_preferences/shared_preferences.dart';

import '../models/task.dart';

/// Lightweight UI preference store for the last-selected alarm tone.
///
/// This is intentionally separate from Hive task models and TypeAdapters so
/// that alarm-tone history does not leak into persisted task records.
class UserPreferencesService {
  UserPreferencesService._();

  static final UserPreferencesService instance = UserPreferencesService._();
  SharedPreferences? _prefs;

  static const _kAlarmSoundType = 'last_alarm_sound_type';
  static const _kAlarmSoundId = 'last_alarm_sound_id';
  static const _kAlarmSoundUri = 'last_alarm_sound_uri';

  /// Initialises the underlying SharedPreferences instance. Call once at app
  /// startup before reading or writing preferences.
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Returns the last-selected alarm sound for pre-filling new alarmed tasks,
  /// or null if none has been saved yet.
  SavedAlarmPreference? getLastAlarmSound() {
    if (_prefs == null) return null;
    final typeName = _prefs!.getString(_kAlarmSoundType);
    if (typeName == null) return null;
    try {
      return SavedAlarmPreference(
        uri: _prefs!.getString(_kAlarmSoundUri),
        label: _prefs!.getString(_kAlarmSoundId) ?? 'System alarm',
        type: AlarmSoundType.values.byName(typeName),
      );
    } on ArgumentError {
      // Stale type name – treat as no saved preference.
      return null;
    }
  }

  /// Persists the user's most recent alarm sound choice so future new tasks
  /// default to it.
  Future<void> saveLastAlarmSound(SavedAlarmPreference selection) async {
    if (_prefs == null) return;
    await _prefs!.setString(_kAlarmSoundType, selection.type.name);
    await _prefs!.setString(_kAlarmSoundId, selection.label);
    if (selection.uri != null) { await _prefs!.setString(_kAlarmSoundUri, selection.uri!); }
  }

  /// Clears the saved alarm preference (e.g. on sign-out or reset).
  Future<void> clearLastAlarmSound() async {
    if (_prefs == null) return;
    await _prefs!.remove(_kAlarmSoundType);
    await _prefs!.remove(_kAlarmSoundId);
    await _prefs!.remove(_kAlarmSoundUri);
  }
}

/// Carries an alarm sound selection across the UI layer.
class SavedAlarmPreference {
  const SavedAlarmPreference({
    required this.type,
    required this.label,
    this.uri,
  });

  final AlarmSoundType type;
  final String label;
  final String? uri;
}
