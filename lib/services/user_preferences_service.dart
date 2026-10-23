import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/task.dart';

/// Built-in alarm tones offered by the in-app picker.
const builtInAlarmSounds = <String, String>{
  'cyber_pulse': 'Cyber Pulse',
  'gentle_bell': 'Gentle Bell',
  'subtle_beep': 'Subtle Beep',
};

/// A remembered tone can preselect a new alarmed task only while it still
/// matches a tone the in-app picker can show.
@visibleForTesting
bool canUseRememberedAlarmTone(SavedAlarmPreference selection) {
  switch (selection.type) {
    case AlarmSoundType.builtIn:
      return builtInAlarmSounds.containsKey(selection.soundId);
    case AlarmSoundType.system:
    case AlarmSoundType.customFile:
      final uri = selection.uri;
      return uri != null && uri.isNotEmpty;
  }
}

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
    final SavedAlarmPreference saved;
    try {
      saved = SavedAlarmPreference(
        uri: _prefs!.getString(_kAlarmSoundUri),
        soundId: _prefs!.getString(_kAlarmSoundId) ?? '',
        type: AlarmSoundType.values.byName(typeName),
      );
    } on ArgumentError {
      // Stale type name – treat as no saved preference.
      return null;
    }
    if (!canUseRememberedAlarmTone(saved)) return null;
    return saved;
  }

  /// Persists the user's most recent alarm sound choice so future new tasks
  /// default to it. An unavailable or incomplete choice is left untouched.
  Future<void> saveLastAlarmSound(SavedAlarmPreference selection) async {
    if (_prefs == null || !canUseRememberedAlarmTone(selection)) return;
    await _prefs!.setString(_kAlarmSoundType, selection.type.name);
    await _prefs!.setString(_kAlarmSoundId, selection.soundId);
    final uri = selection.uri;
    if (uri != null && uri.isNotEmpty) {
      await _prefs!.setString(_kAlarmSoundUri, uri);
    } else {
      await _prefs!.remove(_kAlarmSoundUri);
    }
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
    required this.soundId,
    this.uri,
  });

  final AlarmSoundType type;
  final String soundId;
  final String? uri;
}
