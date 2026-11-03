import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Canonical parity and its UI code. Stored booleans/strings describe the
/// actual parity; changing the displayed code never changes that schedule.
enum WeekParity {
  even(false, 'even', 'Z', 'Even', 'زوج'),
  odd(true, 'odd', 'F', 'Odd', 'فرد');

  const WeekParity(this.isOdd, this.storageValue, this.code, this.englishName,
      this.persianName);

  final bool isOdd;
  final String storageValue;
  final String code;
  final String englishName;
  final String persianName;

  static WeekParity fromOdd(bool odd) => odd ? WeekParity.odd : WeekParity.even;

  static WeekParity? fromStorage(String value) => switch (value) {
        'even' => WeekParity.even,
        'odd' => WeekParity.odd,
        _ => null,
      };

  String get englishCurrentLabel => 'Current week: $englishName ($code)';
  String get persianCurrentLabel => 'هفته جاری: $persianName ($code)';
  String get persianChoiceLabel => 'هفته $persianName ($code)';
  String get englishWeekLabel => '$code week';
  String get englishWeeksLabel => '$code weeks';
}

/// Saturday that begins the calendar week containing [date].
///
/// Time of day is discarded. The result is a local date at midnight.
DateTime saturdayStartingWeek(DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  final sinceSaturday = (day.weekday - DateTime.saturday + 7) % 7;
  return DateTime(day.year, day.month, day.day - sinceSaturday);
}

/// Whole Saturday-to-Saturday weeks from [anchorSaturday] to [date].
///
/// The count uses calendar dates, so a daylight-saving shift cannot change it.
int elapsedSaturdayWeeks(DateTime anchorSaturday, DateTime date) {
  final current = saturdayStartingWeek(date);
  final anchor = saturdayStartingWeek(anchorSaturday);
  final days = DateTime.utc(current.year, current.month, current.day)
      .difference(DateTime.utc(anchor.year, anchor.month, anchor.day))
      .inDays;
  return days ~/ 7;
}

/// Whether a plan entry runs during the week described by [oddWeek].
///
/// `odd` is F and `even` is Z. An every-week plan runs regardless of parity.
bool planEntryRunsThisWeek({
  required bool everyWeek,
  required String weeks,
  required bool oddWeek,
}) {
  if (everyWeek || weeks == 'both') return true;
  return WeekParity.fromStorage(weeks) == WeekParity.fromOdd(oddWeek);
}

/// Global Z/F cycle. Odd weeks are F and even weeks are Z.
class WeekCycleService extends ChangeNotifier {
  WeekCycleService(this._prefs);

  static const configuredKey = 'week_cycle_configured';
  static const anchorKey = 'week_cycle_anchor_saturday';
  static const anchorOddKey = 'week_cycle_anchor_odd';

  final SharedPreferences _prefs;
  Timer? _timer;
  bool? _observedOdd;

  static Future<WeekCycleService> load() async =>
      WeekCycleService(await SharedPreferences.getInstance());

  bool get isConfigured {
    if (_prefs.getBool(configuredKey) != true) return false;
    return _prefs.getBool(anchorOddKey) != null && _readAnchor() != null;
  }

  DateTime? get anchorSaturday => _readAnchor();

  /// True when the anchor Saturday was saved as an odd (F) week.
  bool get anchorOdd => _prefs.getBool(anchorOddKey) ?? true;

  bool isOddOn(DateTime date) {
    final anchor = anchorSaturday;
    if (!isConfigured || anchor == null) {
      throw StateError('Week cycle is not configured.');
    }
    final elapsed = elapsedSaturdayWeeks(anchor, date);
    return elapsed.isEven ? anchorOdd : !anchorOdd;
  }

  String currentWeekLabel([DateTime? now]) =>
      WeekParity.fromOdd(isOddOn(now ?? DateTime.now())).persianCurrentLabel;

  /// Saves [odd] as the week containing [now] and anchors that Saturday.
  Future<void> chooseCurrentWeek(bool odd, {DateTime? now}) async {
    final saturday = saturdayStartingWeek(now ?? DateTime.now());
    await _prefs.setString(anchorKey, _formatDate(saturday));
    await _prefs.setBool(anchorOddKey, odd);
    await _prefs.setBool(configuredKey, true);
    _observedOdd = odd;
    notifyListeners();
  }

  /// Clears the saved cycle so the first-launch choice is required again.
  Future<void> reset() async {
    await _prefs.remove(configuredKey);
    await _prefs.remove(anchorKey);
    await _prefs.remove(anchorOddKey);
    _observedOdd = null;
    notifyListeners();
  }

  void start() {
    if (isConfigured) _observedOdd = isOddOn(DateTime.now());
    _timer ??= Timer.periodic(const Duration(minutes: 1), (_) => refresh());
  }

  /// Notifies listeners when a Saturday boundary changes the active week.
  void refresh() {
    if (!isConfigured) return;
    final odd = isOddOn(DateTime.now());
    if (odd == _observedOdd) return;
    _observedOdd = odd;
    notifyListeners();
  }

  DateTime? _readAnchor() {
    final raw = _prefs.getString(anchorKey);
    if (raw == null) return null;
    final parts = raw.split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return saturdayStartingWeek(date) == date ? date : null;
  }

  String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
