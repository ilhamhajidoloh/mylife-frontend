import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  static const String _prefix = 'cache_';
  static const Duration _defaultTtl = Duration(hours: 24);

  static String _key(String userId, String module) => '$_prefix${userId}_$module';

  static Future<void> save(String userId, String module, dynamic data) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode({
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    });
    await prefs.setString(_key(userId, module), payload);
  }

  static Future<dynamic> get(String userId, String module, {Duration? ttl}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(userId, module));
    if (raw == null) return null;

    try {
      final decoded = jsonDecode(raw);
      final timestamp = DateTime.parse(decoded['timestamp']);
      final effectiveTtl = ttl ?? _defaultTtl;
      if (DateTime.now().difference(timestamp) > effectiveTtl) {
        await prefs.remove(_key(userId, module));
        return null;
      }
      return decoded['data'];
    } catch (_) {
      return null;
    }
  }

  static Future<void> remove(String userId, String module) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(userId, module));
  }

  static Future<void> clearUser(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('$_prefix${userId}_'));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  // Module names
  static const finance = 'finance';
  static const financeSummary = 'finance_summary';
  static const financeRecurring = 'finance_recurring';
  static const scheduleTerms = 'schedule_terms';
  static const scheduleTodayClasses = 'schedule_today_classes';
  static const activities = 'activities';
  static const activityTimeline = 'activity_timeline';
  static const todos = 'todos';
  static const todoDailyCompletion = 'todo_daily';
  static const tasks = 'tasks';
  static const taskUrgent = 'task_urgent';
  static const healthChart = 'health_chart';
}
