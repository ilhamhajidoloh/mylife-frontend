import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'logger.dart';

/// อ่านจำนวนก้าวเดินจริงจากเซนเซอร์นับก้าวของเครื่อง (ผ่านแพ็กเกจ pedometer)
///
/// เซนเซอร์นับก้าวสะสมตั้งแต่เครื่องเปิด (boot) ไม่ได้รีเซ็ตรายวัน
/// จึงต้องเก็บค่า "ฐาน" (baseline) ของวันนี้ไว้ แล้วคำนวณก้าววันนี้ = ค่าปัจจุบัน - ค่าฐาน
class PedometerService {
  static StreamSubscription<StepCount>? _subscription;
  static int? _baselineSteps;
  static bool _isAvailable = true;

  static final ValueNotifier<int> todaySteps = ValueNotifier<int>(0);

  static const _prefBaselineDate = 'pedometer_baseline_date';
  static const _prefBaselineSteps = 'pedometer_baseline_steps';

  static bool get isAvailable => _isAvailable;

  static String _todayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

  static Future<bool> requestPermission() async {
    final status = await Permission.activityRecognition.request();
    return status.isGranted;
  }

  static Future<void> start() async {
    if (_subscription != null) return; // เริ่มไปแล้ว ไม่ต้องเริ่มซ้ำ

    final granted = await requestPermission();
    if (!granted) {
      _isAvailable = false;
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final storedDate = prefs.getString(_prefBaselineDate);
    final todayKey = _todayKey(DateTime.now());
    _baselineSteps = storedDate == todayKey ? prefs.getInt(_prefBaselineSteps) : null;

    try {
      _subscription = Pedometer.stepCountStream.listen(
        _onStepCount,
        onError: (e) {
          _isAvailable = false;
          Logger.catchBlock('PedometerService', 'stepCountStream', e, StackTrace.current);
        },
        cancelOnError: false,
      );
    } catch (e, st) {
      _isAvailable = false;
      Logger.catchBlock('PedometerService', 'start', e, st);
    }
  }

  static Future<void> _onStepCount(StepCount event) async {
    final prefs = await SharedPreferences.getInstance();
    final todayKey = _todayKey(event.timeStamp);
    final storedDate = prefs.getString(_prefBaselineDate);

    if (_baselineSteps == null || storedDate != todayKey) {
      // วันใหม่ (หรือยังไม่เคยตั้งฐาน) — เริ่มนับจากค่าปัจจุบันของวันนี้
      _baselineSteps = event.steps;
      await prefs.setString(_prefBaselineDate, todayKey);
      await prefs.setInt(_prefBaselineSteps, _baselineSteps!);
    } else if (event.steps < _baselineSteps!) {
      // เครื่องน่าจะรีสตาร์ทระหว่างวัน ค่าสะสมรีเซ็ต ให้เริ่มฐานใหม่จากค่าปัจจุบัน
      _baselineSteps = event.steps;
      await prefs.setInt(_prefBaselineSteps, _baselineSteps!);
    }

    final delta = event.steps - _baselineSteps!;
    todaySteps.value = delta < 0 ? 0 : delta;
  }

  static void stop() {
    _subscription?.cancel();
    _subscription = null;
  }
}
