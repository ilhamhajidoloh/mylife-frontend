import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'logger.dart';

class SystemNotification {
  final String title;
  final String message;
  final IconData icon;
  final Color color;

  SystemNotification({
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
  });
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const String _channelId = 'mylife_notifications';
  static const String _channelName = 'MyLife Notifications';
  static const String _channelDesc = 'Notifications for MyLife schedule, tasks and activities';

  static Future<void> init() async {
    if (_initialized) return;

    try {
      // 1. Initialize timezone
      tz.initializeTimeZones();
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Bangkok'));
      } catch (_) {
        tz.setLocalLocation(tz.getLocation('UTC'));
      }

      // 2. Android Initialization Settings
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

      // 3. iOS Initialization Settings
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notificationsPlugin.initialize(
        settings,
        onDidReceiveNotificationResponse: (details) {
          Logger.info('NotificationService', 'Notification tapped: ${details.payload}');
        },
      );

      // 4. Request Android 13+ Notification Permission
      final androidPlugin = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.requestNotificationsPermission();
        await androidPlugin.requestExactAlarmsPermission();
      }

      _initialized = true;
      Logger.info('NotificationService', 'NotificationService initialized successfully');
    } catch (e, st) {
      Logger.catchBlock('NotificationService', 'init', e, st);
    }
  }

  static NotificationDetails _notificationDetails() {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    return const NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
  }

  /// แสดงการแจ้งเตือนทันที
  static Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      await _notificationsPlugin.show(
        id,
        title,
        body,
        _notificationDetails(),
        payload: payload,
      );
    } catch (e, st) {
      Logger.catchBlock('NotificationService', 'showInstantNotification', e, st);
    }
  }

  /// ตั้งเวลาแจ้งเตือนตามวันที่กำหนด (One-time)
  static Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    try {
      if (scheduledDate.isBefore(DateTime.now())) return;

      final tzDate = tz.TZDateTime.from(scheduledDate, tz.local);
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tzDate,
        _notificationDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
      Logger.info('NotificationService', 'Scheduled notification #$id for $scheduledDate');
    } catch (e, st) {
      Logger.catchBlock('NotificationService', 'scheduleNotification', e, st);
    }
  }

  /// ตั้งเวลาแจ้งเตือนรายสัปดาห์ (สำหรับตารางเรียน เช่น ก่อนเริ่มเรียน 15 นาที)
  /// [dayOfWeek]: 1 = Monday .. 7 = Sunday
  static Future<void> scheduleWeeklyCourseNotification({
    required int id,
    required String title,
    required String body,
    required int dayOfWeek,
    required int hour,
    required int minute,
    int advanceMinutes = 15,
  }) async {
    try {
      var targetMinute = minute - advanceMinutes;
      var targetHour = hour;
      if (targetMinute < 0) {
        targetMinute += 60;
        targetHour -= 1;
      }

      if (targetHour < 0) {
        targetHour += 24;
        dayOfWeek = dayOfWeek == 1 ? 7 : dayOfWeek - 1;
      }

      final now = DateTime.now();
      var scheduledDate = DateTime(now.year, now.month, now.day, targetHour, targetMinute);

      while (scheduledDate.weekday != dayOfWeek || scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      final tzDate = tz.TZDateTime(
        tz.local,
        scheduledDate.year,
        scheduledDate.month,
        scheduledDate.day,
        scheduledDate.hour,
        scheduledDate.minute,
      );

      try {
        await _notificationsPlugin.zonedSchedule(
          id,
          title,
          body,
          tzDate,
          _notificationDetails(),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      } catch (e) {
        // หากเครื่องปฏิเสธสิทธิ์ Exact Alarm บน Android 12+ ให้ Fallback ไปใช้ inexactAllowWhileIdle
        await _notificationsPlugin.zonedSchedule(
          id,
          title,
          body,
          tzDate,
          _notificationDetails(),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      }

      Logger.info('NotificationService', 'Scheduled weekly course notification #$id for $scheduledDate (TZ: $tzDate)');
    } catch (e, st) {
      Logger.catchBlock('NotificationService', 'scheduleWeeklyCourseNotification', e, st);
    }
  }

  /// ตั้งเวลาแจ้งเตือนสำหรับกิจกรรม — รองรับทั้งครั้งเดียวและทำซ้ำ (รายวัน/สัปดาห์/เดือน)
  /// [matchComponents] เป็น null หมายถึงแจ้งเตือนครั้งเดียว, ไม่ null หมายถึงทำซ้ำตาม pattern นั้น
  static Future<void> scheduleActivityNotification({
    required int id,
    required String title,
    required String body,
    required DateTime occurrence,
    DateTimeComponents? matchComponents,
  }) async {
    try {
      var scheduled = occurrence;
      final now = DateTime.now();

      if (matchComponents != null) {
        var guard = 0;
        while (scheduled.isBefore(now) && guard < 1000) {
          switch (matchComponents) {
            case DateTimeComponents.time:
              scheduled = scheduled.add(const Duration(days: 1));
              break;
            case DateTimeComponents.dayOfWeekAndTime:
              scheduled = scheduled.add(const Duration(days: 7));
              break;
            case DateTimeComponents.dayOfMonthAndTime:
              scheduled = DateTime(scheduled.year, scheduled.month + 1, scheduled.day, scheduled.hour, scheduled.minute);
              break;
            default:
              scheduled = scheduled.add(const Duration(days: 1));
          }
          guard++;
        }
      } else if (scheduled.isBefore(now)) {
        return;
      }

      final tzDate = tz.TZDateTime.from(scheduled, tz.local);
      try {
        await _notificationsPlugin.zonedSchedule(
          id,
          title,
          body,
          tzDate,
          _notificationDetails(),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: matchComponents,
        );
      } catch (_) {
        await _notificationsPlugin.zonedSchedule(
          id,
          title,
          body,
          tzDate,
          _notificationDetails(),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: matchComponents,
        );
      }

      Logger.info('NotificationService', 'Scheduled activity notification #$id for $scheduled');
    } catch (e, st) {
      Logger.catchBlock('NotificationService', 'scheduleActivityNotification', e, st);
    }
  }

  /// ดึงข้อมูลการแจ้งเตือนสดสำหรับหน้าต่างแสดงผล
  static Future<List<SystemNotification>> fetchNotificationsFromServer(String userId) async {
    try {
      return [
        SystemNotification(
          title: 'ยินดีต้อนรับสู่ MyLife',
          message: 'ระบบพร้อมใช้งานและการแจ้งเตือนทำงานอย่างปกติ',
          icon: Icons.notifications_active_rounded,
          color: const Color(0xFF6366F1),
        ),
      ];
    } catch (_) {
      return [];
    }
  }

  /// ยกเลิกการแจ้งเตือนตาม ID
  static Future<void> cancelNotification(int id) async {
    try {
      await _notificationsPlugin.cancel(id);
    } catch (e, st) {
      Logger.catchBlock('NotificationService', 'cancelNotification', e, st);
    }
  }

  /// ยกเลิกการแจ้งเตือนทั้งหมด
  static Future<void> cancelAll() async {
    try {
      await _notificationsPlugin.cancelAll();
    } catch (e, st) {
      Logger.catchBlock('NotificationService', 'cancelAll', e, st);
    }
  }
}
