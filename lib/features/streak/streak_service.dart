import 'package:shared_preferences/shared_preferences.dart';

class StreakData {
  final int current;
  final int best;

  const StreakData({required this.current, required this.best});
}

class StreakService {
  static const _keyLast   = 'streak_last_date';
  static const _keyCurrent = 'streak_current';
  static const _keyBest    = 'streak_best';

  /// Call every time a transaction is saved.
  static Future<StreakData> recordActivity() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _dateKey(DateTime.now());
    final last  = prefs.getString(_keyLast);

    int current = prefs.getInt(_keyCurrent) ?? 0;
    int best    = prefs.getInt(_keyBest) ?? 0;

    if (last == today) {
      // Already counted today
      return StreakData(current: current, best: best);
    }

    if (last == _dateKey(DateTime.now().subtract(const Duration(days: 1)))) {
      // Consecutive day
      current += 1;
    } else {
      // Gap → reset
      current = 1;
    }

    best = current > best ? current : best;

    await prefs.setString(_keyLast, today);
    await prefs.setInt(_keyCurrent, current);
    await prefs.setInt(_keyBest, best);

    return StreakData(current: current, best: best);
  }

  /// Read current streak without modifying it.
  static Future<StreakData> load() async {
    final prefs   = await SharedPreferences.getInstance();
    final last    = prefs.getString(_keyLast);
    int current   = prefs.getInt(_keyCurrent) ?? 0;
    final best    = prefs.getInt(_keyBest) ?? 0;

    // If last activity was not today or yesterday, streak is broken
    if (last != null) {
      final lastDate = DateTime.tryParse(last);
      if (lastDate != null) {
        final diff = DateTime.now().difference(lastDate).inDays;
        if (diff > 1) current = 0;
      }
    }

    return StreakData(current: current, best: best);
  }

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
