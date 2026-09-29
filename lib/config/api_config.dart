import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConfig {
  // อ่านค่าจาก --dart-define=API_BASE_URL=https://your-production-domain.com
  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');

  // URL ของ Render Cloud Server
  static const String _renderUrl =
      'https://mylife-backend-1015105923446.asia-southeast1.run.app';

  static String get baseUrl {
    // 1. ถ้ามีการระบุ API_BASE_URL ตอน build ให้ใช้ค่านั้นทันที
    if (_envBaseUrl.isNotEmpty) {
      return _envBaseUrl;
    }

    // 2. ถ้าเป็น Release Mode (ตอน Build APK / Deploy ใช้งานจริง) ให้ชี้ไปที่ Render Cloud เสมอ 100%
    if (kReleaseMode) {
      return _renderUrl;
    }

    // 3. ถ้าเป็น Web (Debug Mode)
    if (kIsWeb) {
      return 'http://localhost:5147';
    }

    // 4. ถ้าเป็น Android / iOS (Debug Mode)
    if (Platform.isAndroid || Platform.isIOS) {
      const bool isEmulator = bool.fromEnvironment(
        'IS_EMULATOR',
        defaultValue: false,
      );
      if (isEmulator) {
        return 'http://10.0.2.2:5147'; // Localhost สำหรับ Android Emulator
      }

      // ถ้าเป็นโทรศัพท์จริงใน Debug Mode ให้ดึงข้อมูลจาก Render Cloud Server
      return _renderUrl;
    }

    // 5. สำหรับ Windows / macOS / Linux (Debug Mode)
    return 'http://localhost:5147';
  }

  // Endpoints ทั้งหมดในระบบ
  static String get authRegister => '$baseUrl/api/auth/register';
  static String get authLogin => '$baseUrl/api/auth/login';
  static String get authSocialLogin => '$baseUrl/api/auth/social-login';
  static String get authMe => '$baseUrl/api/auth/me';
  static String get authProfile => '$baseUrl/api/auth/profile';
  static String get authPassword => '$baseUrl/api/auth/password';
  static String get authProfileImage => '$baseUrl/api/auth/profile-image';
  static String authProfileImageUrl(String userId) =>
      '$baseUrl/api/auth/profile-image/$userId';

  static String finance(String userId) => '$baseUrl/api/finance/$userId';
  static String financeSummary(String userId) =>
      '$baseUrl/api/finance/summary/$userId';
  static String financeRecurring(String userId) =>
      '$baseUrl/api/finance/recurring/$userId';
  static String get financeRecurringAdd => '$baseUrl/api/finance/recurring';
  static String financeRecurringItem(String id) =>
      '$baseUrl/api/finance/recurring/$id';
  static String financeBreakdown(
    String userId,
    String period, {
    int? year,
    int? month,
  }) {
    final params = <String, String>{'period': period};
    if (year != null) params['year'] = '$year';
    if (month != null) params['month'] = '$month';
    final query = params.entries.map((e) => '${e.key}=${e.value}').join('&');
    return '$baseUrl/api/finance/breakdown/$userId?$query';
  }

  // Books API
  static String books(String userId) => '$baseUrl/api/books/$userId';
  static String get bookCreate => '$baseUrl/api/books';
  static String bookItem(String id) => '$baseUrl/api/books/$id';

  static String scheduleTerms(String userId) =>
      '$baseUrl/api/schedule/terms/$userId';
  static String scheduleTodayClasses(String userId) =>
      '$baseUrl/api/schedule/today-classes/$userId';
  static String get scheduleTermCreate => '$baseUrl/api/schedule/terms';
  static String scheduleTermItem(String id) =>
      '$baseUrl/api/schedule/terms/$id';
  static String scheduleByTerm(String userId, String termId) =>
      '$baseUrl/api/schedule/$userId/term/$termId';
  static String scheduleStats(String userId, String termId) =>
      '$baseUrl/api/schedule/stats/$userId/$termId';

  static String activity(String userId) => '$baseUrl/api/activity/$userId';
  static String activityTimeline(String userId) =>
      '$baseUrl/api/activity/timeline/$userId';

  static String todo(String userId) => '$baseUrl/api/todo/$userId';
  static String todoDailyCompletion(String userId) =>
      '$baseUrl/api/todo/daily-completion/$userId';

  static String task(String userId) => '$baseUrl/api/task/$userId';
  static String taskUrgent(String userId) => '$baseUrl/api/task/urgent/$userId';

  static String health(String userId) => '$baseUrl/api/health/$userId';
  static String healthChartData(String userId) =>
      '$baseUrl/api/health/chart-data/$userId';

  static String googleCalendar(String userId) =>
      '$baseUrl/api/googlecalendar/$userId';
  static String googleCalendarConnect(String userId) =>
      '$baseUrl/api/googlecalendar/$userId/connect';

  static String lineConnection(String userId) => '$baseUrl/api/line/$userId';
  static String lineConnect(String userId) =>
      '$baseUrl/api/line/$userId/connect';
  static String lineDisconnect(String userId) =>
      '$baseUrl/api/line/$userId/disconnect';
  static String lineTest(String userId) => '$baseUrl/api/line/$userId/test';

  static String notification(String userId) =>
      '$baseUrl/api/notification/$userId';

  static String emailPreferences(String userId) =>
      '$baseUrl/api/emailnotification/$userId/preferences';
  static String emailTest(String userId) => '$baseUrl/api/emailnotification/$userId/test';
}
