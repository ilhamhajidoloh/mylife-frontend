import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../services/api_client.dart';
import '../services/api_services.dart';
import '../services/user_session.dart';
import '../services/cache_service.dart';
import '../services/logger.dart';
import '../services/data_event_service.dart';
import '../services/notification_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    show DateTimeComponents;

enum ActivityTimeType { timed, allDay, multiDay, noDate, recurring }

class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key});

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  bool _isLoading = true;
  List<dynamic> _activities = [];
  Map<String, dynamic>? _timeline;

  late Timer _timer;
  Duration _remainingTime = Duration.zero;

  void _updateRemainingTime() {
    if (_timeline != null &&
        _timeline!['next'] != null &&
        _timeline!['next']['startTime'] != null) {
      final startTimeStr = _timeline!['next']['startTime'].toString();
      final targetDate = DateTime.tryParse(startTimeStr)?.toLocal();
      if (targetDate != null) {
        final diff = targetDate.difference(DateTime.now());
        _remainingTime = diff.isNegative ? Duration.zero : diff;
        return;
      }
    }
    if (_timeline != null && _timeline!['countdownSeconds'] != null) {
      final sec =
          num.tryParse(_timeline!['countdownSeconds'].toString())?.toInt() ?? 0;
      _remainingTime = Duration(seconds: sec > 0 ? sec : 0);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadActivities();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_timeline != null &&
              _timeline!['next'] != null &&
              _timeline!['next']['startTime'] != null) {
            _updateRemainingTime();
          } else if (_remainingTime.inSeconds > 0) {
            _remainingTime -= const Duration(seconds: 1);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _loadActivities() async {
    final userId = await UserSession.getUserId();

    // 1. อ่านข้อมูลจาก Cache ก่อน
    final cachedAct = await CacheService.get(userId, CacheService.activities);
    if (cachedAct != null && cachedAct is List) _activities = cachedAct;

    final cachedTimeline = await CacheService.get(
      userId,
      CacheService.activityTimeline,
    );
    if (cachedTimeline != null) {
      _timeline = cachedTimeline is Map<String, dynamic>
          ? cachedTimeline
          : Map<String, dynamic>.from(cachedTimeline as Map);
      _updateRemainingTime();
    }

    if (cachedAct != null || cachedTimeline != null) {
      if (mounted) setState(() => _isLoading = false);
    } else {
      if (mounted) setState(() => _isLoading = true);
    }

    try {
      final list = await ActivityApiService.getActivities(userId);
      if (list != null && list is List) {
        _activities = list;
        await CacheService.save(userId, CacheService.activities, list);
        await _rescheduleAllActivityNotifications();
      }

      final timeline = await ActivityApiService.getTimeline(userId);
      if (timeline != null) {
        _timeline = timeline is Map<String, dynamic>
            ? timeline
            : Map<String, dynamic>.from(timeline as Map);
        await CacheService.save(
          userId,
          CacheService.activityTimeline,
          timeline,
        );
      }

      _updateRemainingTime();
    } catch (e, st) {
      Logger.catchBlock('ActivityPage', 'loadActivities', e, st);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _rescheduleAllActivityNotifications() async {
    for (final act in _activities) {
      await _scheduleActivityNotification(act);
    }
  }

  /// ตั้ง/ยกเลิกการแจ้งเตือนของกิจกรรมตามประเภทเวลา — ไม่ระบุวันจะไม่มีแจ้งเตือน,
  /// ทั้งวันแจ้งตอน 8 โมงเช้าของวันนั้น, ที่เหลือแจ้งก่อนเริ่ม 15 นาที (ทำซ้ำตาม recurrence ถ้ามี)
  int _parseRecurrence(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
      switch (value.trim()) {
        case 'ทุกวัน':
        case 'daily':
          return 1;
        case 'ทุกสัปดาห์':
        case 'weekly':
          return 2;
        case 'ทุกเดือน':
        case 'monthly':
          return 3;
        case 'ทุกปี':
        case 'yearly':
          return 4;
        default:
          return 0;
      }
    }
    return 0;
  }

  /// ตั้ง/ยกเลิกการแจ้งเตือนของกิจกรรมตามประเภทเวลา — ไม่ระบุวันจะไม่มีแจ้งเตือน,
  /// ทั้งวันแจ้งตอน 8 โมงเช้าของวันนั้น, ที่เหลือแจ้งก่อนเริ่ม 15 นาที (ทำซ้ำตาม recurrence ถ้ามี)
  Future<void> _scheduleActivityNotification(dynamic act) async {
    try {
      final id = act['id'];
      if (id == null) return;
      final notifId = (id.toString().hashCode).abs() % 2147483647;

      if (act['isIndefinite'] == true ||
          act['isIndefinite'] == 'true' ||
          act['startTime'] == null) {
        await NotificationService.cancelNotification(notifId);
        return;
      }

      final start = DateTime.tryParse(act['startTime'].toString())?.toLocal();
      if (start == null) return;
      final title = act['title']?.toString() ?? 'กิจกรรม';
      final location = act['location']?.toString() ?? '';

      if (act['isAllDay'] == true || act['isAllDay'] == 'true') {
        final reminderTime = DateTime(start.year, start.month, start.day, 8, 0);
        await NotificationService.scheduleActivityNotification(
          id: notifId,
          title: '📅 วันนี้มีกิจกรรม: $title',
          body: location.isNotEmpty ? 'ที่ $location' : 'กิจกรรมตลอดทั้งวัน',
          occurrence: reminderTime,
        );
        return;
      }

      final reminderTime = start.subtract(const Duration(minutes: 15));
      final recurrence = _parseRecurrence(act['recurrence']);
      DateTimeComponents? matchComponents;
      switch (recurrence) {
        case 1:
          matchComponents = DateTimeComponents.time; // ทุกวัน
          break;
        case 2:
          matchComponents = DateTimeComponents.dayOfWeekAndTime; // ทุกสัปดาห์
          break;
        case 3:
          matchComponents = DateTimeComponents.dayOfMonthAndTime; // ทุกเดือน
          break;
        default:
          matchComponents = null; // ทุกปี หรือไม่ทำซ้ำ -> แจ้งครั้งเดียว
      }

      await NotificationService.scheduleActivityNotification(
        id: notifId,
        title: '⏰ กิจกรรมใกล้เริ่ม: $title',
        body:
            'จะเริ่มเวลา ${_formatTime(start)} น.${location.isNotEmpty ? ' ที่ $location' : ''}',
        occurrence: reminderTime,
        matchComponents: matchComponents,
      );
    } catch (e, st) {
      Logger.catchBlock('ActivityPage', 'scheduleActivityNotification', e, st);
    }
  }

  String _formatDuration(Duration d) {
    if (d.inDays > 0) {
      return '${d.inDays} วัน ${d.inHours.remainder(24)} ชม.';
    }
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${twoDigits(d.inHours)}:${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}';
  }

  static const _thMonths = [
    '',
    'ม.ค.',
    'ก.พ.',
    'มี.ค.',
    'เม.ย.',
    'พ.ค.',
    'มิ.ย.',
    'ก.ค.',
    'ส.ค.',
    'ก.ย.',
    'ต.ค.',
    'พ.ย.',
    'ธ.ค.',
  ];

  String _formatDate(DateTime dt) {
    return '${dt.day} ${_thMonths[dt.month]} ${dt.year + 543}';
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    return '${_pad(local.hour)}:${_pad(local.minute)}';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  ActivityTimeType _resolveTimeType(dynamic act) {
    if (act == null) return ActivityTimeType.timed;
    if (act['isIndefinite'] == true ||
        act['isIndefinite'] == 'true' ||
        act['isIndefinite'] == 1)
      return ActivityTimeType.noDate;
    if (act['isMultiDay'] == true ||
        act['isMultiDay'] == 'true' ||
        act['isMultiDay'] == 1)
      return ActivityTimeType.multiDay;
    if (act['isAllDay'] == true ||
        act['isAllDay'] == 'true' ||
        act['isAllDay'] == 1) {
      return ActivityTimeType.allDay;
    }
    final recurrence = _parseRecurrence(act['recurrence']);
    if (recurrence != 0) return ActivityTimeType.recurring;
    return ActivityTimeType.timed;
  }

  /// คำนวณ progress สำหรับกิจกรรมที่กำลังดำเนินการ (หลอดลดลงตามเวลาที่เหลือ)
  double? _calculateOngoingProgress(dynamic act) {
    if (act == null) return null;
    final startStr = act['startTime']?.toString();
    final endStr = act['endTime']?.toString();
    if (startStr == null || endStr == null) return null;
    final start = DateTime.tryParse(startStr)?.toLocal();
    final end = DateTime.tryParse(endStr)?.toLocal();
    if (start == null || end == null || !end.isAfter(start)) return null;

    final totalSec = end.difference(start).inSeconds;
    if (totalSec <= 0) return null;
    final now = DateTime.now();
    final remSec = end.difference(now).inSeconds;
    // หลอดลดลงตามเวลาที่เหลือ (1.0 เมื่อเริ่ม -> 0.0 เมื่อหมดเวลา)
    return (remSec / totalSec).clamp(0.0, 1.0);
  }

  /// คำนวณ progress สำหรับกิจกรรมถัดไป (หลอดเพิ่มขึ้นในรอบ 30 วัน ถ้ายังไม่ถึง 30 วัน ไม่ต้องขึ้น)
  double? _calculateNextActivityProgress(dynamic act, Duration remaining) {
    if (act == null) return null;
    final remSec = remaining.inSeconds;
    const thirtyDaysInSeconds = 30 * 24 * 3600; // 2,592,000 วินาที

    // ถ้าเหลือมากกว่า 30 วัน (ยังไม่ถึงรอบ 30 วัน) -> ไม่ต้องแสดง progress bar
    if (remSec > thirtyDaysInSeconds) return null;
    if (remSec <= 0) return 1.0;

    // หลอดเพิ่มขึ้นตามเวลาที่นับถอยหลังเข้าใกล้เวลาเริ่ม (0% ที่ 30 วัน -> 100% เมื่อถึงเวลา)
    return (1.0 - (remSec / thirtyDaysInSeconds)).clamp(0.0, 1.0);
  }

  void _openActivityModal([dynamic item]) {
    final isEdit = item != null;
    final titleController = TextEditingController(
      text: item?['title']?.toString() ?? '',
    );
    final descController = TextEditingController(
      text: item?['description']?.toString() ?? '',
    );
    final locationController = TextEditingController(
      text: item?['location']?.toString() ?? '',
    );

    ActivityTimeType timeType = isEdit
        ? _resolveTimeType(item)
        : ActivityTimeType.timed;

    DateTime startDate = isEdit && item?['startTime'] != null
        ? (DateTime.tryParse(item!['startTime'].toString())?.toLocal()) ??
              DateTime.now().add(const Duration(hours: 1))
        : DateTime.now().add(const Duration(hours: 1));
    DateTime endDate = isEdit && item?['endTime'] != null
        ? (DateTime.tryParse(item!['endTime'].toString())?.toLocal()) ??
              DateTime.now().add(const Duration(hours: 2))
        : DateTime.now().add(const Duration(hours: 2));
    DateTime multiStartDate = startDate;
    DateTime multiEndDate = endDate;
    int recurrenceType = isEdit ? _parseRecurrence(item?['recurrence']) : 0;

    showAppBottomSheet(
      context,
      title: isEdit ? 'แก้ไขกิจกรรม' : 'เพิ่มกิจกรรมใหม่',
      child: StatefulBuilder(
        builder: (context, setModalState) {
          final cc = context.c;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppModalField(
                controller: titleController,
                label: 'ชื่อกิจกรรม',
                icon: Icons.event_rounded,
              ),
              const SizedBox(height: 12),
              AppModalField(
                controller: descController,
                label: 'รายละเอียด',
                icon: Icons.description_rounded,
              ),
              const SizedBox(height: 12),
              AppModalField(
                controller: locationController,
                label: 'สถานที่',
                icon: Icons.location_on_rounded,
              ),
              const SizedBox(height: 20),

              // Time Type Selection
              AppModalSection(
                title: 'ประเภทเวลา',
                child: Column(
                  children: [
                    _timeTypeRadioCard(
                      ActivityTimeType.timed,
                      Icons.schedule_rounded,
                      'ระบุเวลา',
                      'เลือกเวลาเริ่ม-สิ้นสุด',
                      timeType,
                      cc,
                      (val) => setModalState(() => timeType = val),
                    ),
                    _timeTypeRadioCard(
                      ActivityTimeType.allDay,
                      Icons.today_rounded,
                      'ทั้งวัน',
                      'กิจกรรมตลอดทั้งวัน',
                      timeType,
                      cc,
                      (val) => setModalState(() => timeType = val),
                    ),
                    _timeTypeRadioCard(
                      ActivityTimeType.multiDay,
                      Icons.date_range_rounded,
                      'ข้ามวัน',
                      'มีวันที่เริ่มต้นและสิ้นสุด',
                      timeType,
                      cc,
                      (val) => setModalState(() => timeType = val),
                    ),
                    _timeTypeRadioCard(
                      ActivityTimeType.noDate,
                      Icons.all_inclusive_rounded,
                      'ไม่ระบุวัน',
                      'ทำไปเรื่อยๆ ไม่มีกำหนด',
                      timeType,
                      cc,
                      (val) => setModalState(() => timeType = val),
                    ),
                    _timeTypeRadioCard(
                      ActivityTimeType.recurring,
                      Icons.repeat_rounded,
                      'ทำซ้ำ',
                      'ทำเป็นรอบรายวัน/สัปดาห์/เดือน/ปี',
                      timeType,
                      cc,
                      (val) => setModalState(() => timeType = val),
                    ),
                  ],
                ),
              ),

              // Pickers based on time type
              if (timeType == ActivityTimeType.timed) ...[
                const SizedBox(height: 16),
                AppModalSection(
                  title: 'วันที่และเวลา',
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cc.surface2,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        _datePickerRow(
                          'วันที่',
                          startDate,
                          cc,
                          (dt) => setModalState(() {
                            startDate = DateTime(
                              dt.year,
                              dt.month,
                              dt.day,
                              startDate.hour,
                              startDate.minute,
                            );
                          }),
                        ),
                        const SizedBox(height: 10),
                        _timePickerRow(
                          'เวลาเริ่ม',
                          startDate,
                          cc,
                          (dt) => setModalState(() => startDate = dt),
                        ),
                        const SizedBox(height: 10),
                        _timePickerRow(
                          'เวลาสิ้นสุด',
                          endDate,
                          cc,
                          (dt) => setModalState(() => endDate = dt),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              if (timeType == ActivityTimeType.allDay) ...[
                const SizedBox(height: 16),
                AppModalSection(
                  title: 'วันที่',
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cc.surface2,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        _datePickerRow(
                          'วันที่',
                          startDate,
                          cc,
                          (dt) => setModalState(() {
                            startDate = DateTime(
                              dt.year,
                              dt.month,
                              dt.day,
                              0,
                              0,
                            );
                            endDate = DateTime(
                              dt.year,
                              dt.month,
                              dt.day,
                              23,
                              59,
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              if (timeType == ActivityTimeType.multiDay) ...[
                const SizedBox(height: 16),
                AppModalSection(
                  title: 'วันที่และเวลา',
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cc.surface2,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        _dateTimePickerRow(
                          'เริ่มต้น',
                          multiStartDate,
                          cc,
                          (dt) => setModalState(() => multiStartDate = dt),
                        ),
                        const SizedBox(height: 10),
                        _dateTimePickerRow(
                          'สิ้นสุด',
                          multiEndDate,
                          cc,
                          (dt) => setModalState(() => multiEndDate = dt),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              if (timeType == ActivityTimeType.recurring) ...[
                const SizedBox(height: 16),
                AppModalSection(
                  title: 'วันที่เริ่มต้น',
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cc.surface2,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: _datePickerRow(
                      'วันที่เริ่ม',
                      startDate,
                      cc,
                      (dt) => setModalState(() {
                        startDate = DateTime(dt.year, dt.month, dt.day, 0, 0);
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                AppModalSection(
                  title: 'ทำซ้ำ',
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cc.surface2,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        _recurrenceOption(
                          'ทุกวัน',
                          1,
                          recurrenceType,
                          cc,
                          (val) => setModalState(() => recurrenceType = val),
                        ),
                        _recurrenceOption(
                          'ทุกสัปดาห์',
                          2,
                          recurrenceType,
                          cc,
                          (val) => setModalState(() => recurrenceType = val),
                        ),
                        _recurrenceOption(
                          'ทุกเดือน',
                          3,
                          recurrenceType,
                          cc,
                          (val) => setModalState(() => recurrenceType = val),
                        ),
                        _recurrenceOption(
                          'ทุกปี',
                          4,
                          recurrenceType,
                          cc,
                          (val) => setModalState(() => recurrenceType = val),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),
              Row(
                children: [
                  if (isEdit) ...[
                    GestureDetector(
                      onTap: () async {
                        await ActivityApiService.deleteActivity(item['id']);
                        final notifId =
                            (item['id'].toString().hashCode).abs() % 2147483647;
                        await NotificationService.cancelNotification(notifId);
                        if (context.mounted) Navigator.pop(context);
                        _loadActivities();
                        DataEventService.notifyDataChanged();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: cc.coralSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.delete_outline_rounded,
                          color: cc.coral,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: AppModalButton(
                      label: 'ยกเลิก',
                      onPressed: () => Navigator.pop(context),
                      isPrimary: false,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppModalButton(
                      label: 'บันทึก',
                      onPressed: () async {
                        if (titleController.text.trim().isEmpty) return;
                        final userId = await UserSession.getUserId();
                        final isAllDay = timeType == ActivityTimeType.allDay;
                        final isMultiDay =
                            timeType == ActivityTimeType.multiDay;
                        final isIndefinite =
                            timeType == ActivityTimeType.noDate;
                        DateTime? finalStart;
                        DateTime? finalEnd;
                        if (timeType == ActivityTimeType.multiDay) {
                          finalStart = multiStartDate;
                          finalEnd = multiEndDate;
                        } else if (timeType != ActivityTimeType.noDate) {
                          finalStart = startDate;
                          finalEnd = endDate;
                        }
                        dynamic saved;
                        if (isEdit && item?['id'] != null) {
                          saved = await ActivityApiService.updateActivity(
                            item!['id'].toString(),
                            userId,
                            titleController.text,
                            descController.text,
                            locationController.text,
                            isAllDay,
                            isMultiDay,
                            isIndefinite,
                            isAllDay
                                ? 'ไม่ทำซ้ำ'
                                : _recurrenceName(recurrenceType),
                            startTime: finalStart,
                            endTime: finalEnd,
                          );
                        } else {
                          saved = await ActivityApiService.addActivity(
                            userId,
                            titleController.text,
                            descController.text,
                            locationController.text,
                            isAllDay,
                            isMultiDay,
                            isIndefinite,
                            isAllDay
                                ? 'ไม่ทำซ้ำ'
                                : _recurrenceName(recurrenceType),
                            startTime: finalStart,
                            endTime: finalEnd,
                          );
                        }
                        if (saved != null)
                          await _scheduleActivityNotification(saved);
                        if (context.mounted) Navigator.pop(context);
                        _loadActivities();
                        DataEventService.notifyDataChanged();
                      },
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  String _recurrenceName(dynamic type) {
    if (type is String && int.tryParse(type) == null) {
      final trimmed = type.trim();
      if (trimmed.isNotEmpty && trimmed != '0') return trimmed;
    }
    final intVal = _parseRecurrence(type);
    switch (intVal) {
      case 1:
        return 'ทุกวัน';
      case 2:
        return 'ทุกสัปดาห์';
      case 3:
        return 'ทุกเดือน';
      case 4:
        return 'ทุกปี';
      default:
        return 'ไม่ทำซ้ำ';
    }
  }

  Widget _timeTypeRadioCard(
    ActivityTimeType type,
    IconData icon,
    String label,
    String desc,
    ActivityTimeType current,
    AppColors c,
    ValueChanged<ActivityTimeType> onChanged,
  ) {
    final selected = type == current;
    return GestureDetector(
      onTap: () => onChanged(type),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? c.accentSoft.withValues(alpha: 0.4) : c.surface2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? c.accent : c.border.withValues(alpha: 0.5),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: selected
                    ? c.accent.withValues(alpha: 0.15)
                    : c.border.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: selected ? c.accent : c.ink3),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: c.ink,
                    ),
                  ),
                  Text(desc, style: TextStyle(fontSize: 12, color: c.ink3)),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? c.accent : Colors.transparent,
                border: Border.all(
                  color: selected ? c.accent : c.border,
                  width: 2,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _datePickerRow(
    String label,
    DateTime current,
    AppColors c,
    ValueChanged<DateTime> onChanged,
  ) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: current,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: Theme.of(
                ctx,
              ).colorScheme.copyWith(primary: c.accent),
            ),
            child: child!,
          ),
        );
        if (picked != null) {
          onChanged(
            DateTime(
              picked.year,
              picked.month,
              picked.day,
              current.hour,
              current.minute,
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.border.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded, size: 18, color: c.accent),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w600, color: c.ink2),
            ),
            const Spacer(),
            Flexible(
              child: Text(
                _formatDate(current),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: c.accent,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timePickerRow(
    String label,
    DateTime current,
    AppColors c,
    ValueChanged<DateTime> onChanged,
  ) {
    return GestureDetector(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(current),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: Theme.of(
                ctx,
              ).colorScheme.copyWith(primary: c.accent),
            ),
            child: child!,
          ),
        );
        if (picked != null) {
          onChanged(
            DateTime(
              current.year,
              current.month,
              current.day,
              picked.hour,
              picked.minute,
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.border.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Icon(Icons.access_time_rounded, size: 18, color: c.accent),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w600, color: c.ink2),
            ),
            const Spacer(),
            Flexible(
              child: Text(
                _formatTime(current),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: c.accent,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateTimePickerRow(
    String label,
    DateTime current,
    AppColors c,
    ValueChanged<DateTime> onChanged,
  ) {
    return GestureDetector(
      onTap: () async {
        final pickedDate = await showDatePicker(
          context: context,
          initialDate: current,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: Theme.of(
                ctx,
              ).colorScheme.copyWith(primary: c.accent),
            ),
            child: child!,
          ),
        );
        if (pickedDate != null && mounted) {
          final pickedTime = await showTimePicker(
            context: context,
            initialTime: TimeOfDay.fromDateTime(current),
            builder: (ctx, child) => Theme(
              data: Theme.of(ctx).copyWith(
                colorScheme: Theme.of(
                  ctx,
                ).colorScheme.copyWith(primary: c.accent),
              ),
              child: child!,
            ),
          );
          if (pickedTime != null) {
            onChanged(
              DateTime(
                pickedDate.year,
                pickedDate.month,
                pickedDate.day,
                pickedTime.hour,
                pickedTime.minute,
              ),
            );
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.border.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded, size: 18, color: c.accent),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w600, color: c.ink2),
            ),
            const Spacer(),
            Flexible(
              child: Text(
                '${_formatDate(current)} ${_formatTime(current)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: c.accent,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recurrenceOption(
    String label,
    int value,
    int current,
    AppColors c,
    ValueChanged<int> onChanged,
  ) {
    final selected = value == current;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? c.accentSoft.withValues(alpha: 0.4)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? c.accent : c.border.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              size: 20,
              color: selected ? c.accent : c.ink3,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: c.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    return Scaffold(
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: c.accentGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: c.accent.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          heroTag: 'fab_activity',
          onPressed: () => _openActivityModal(),
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text(
            'เพิ่มกิจกรรม',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadActivities,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
          children: [
            const PageHeader(
              title: 'กิจกรรม',
              subtitle: 'จัดการกิจกรรมและนับเวลาถอยหลัง',
            ),
            const SizedBox(height: 16),

            if (_isLoading) ...[
              ValueListenableBuilder<bool>(
                valueListenable: ApiClient.isConnectingLong,
                builder: (context, isLong, child) {
                  return ServerConnectingWidget(
                    message: isLong
                        ? 'กำลังปลุกเซิร์ฟเวอร์...'
                        : 'กำลังดึงกิจกรรม...',
                    subMessage: isLong
                        ? 'เซิร์ฟเวอร์กำลังเริ่มต้นทำงาน โปรดรอสักครู่...'
                        : 'กำลังดึงข้อมูลกิจกรรมและกำหนดการของคุณ...',
                  );
                },
              ),
              const SizedBox(height: 16),
              const SkeletonCard(height: 140, borderRadius: 20),
            ] else ...[
              // Countdown Hero Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 26,
                ),
                decoration: BoxDecoration(
                  gradient: c.heroGradient,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: c.accent.withValues(alpha: 0.35),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF4ADE80),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'LIVE COUNTDOWN',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                              color: Colors.white.withValues(alpha: 0.95),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      _formatDuration(_remainingTime),
                      style: const TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 2,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _timeline?['next']?['title']?.toString() ??
                          'ไม่มีกิจกรรมถัดไป',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_timeline?['next']?['location'] != null &&
                        _timeline!['next']['location'].toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.place_rounded,
                                size: 13,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _timeline!['next']['location'].toString(),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // Progress Bar กิจกรรมถัดไป (นับในรอบ 30 วัน ถ้ายังไม่ถึงรอบ 30 วัน จะไม่แสดง)
                    () {
                      final nextProgress = _calculateNextActivityProgress(
                        _timeline?['next'],
                        _remainingTime,
                      );
                      if (nextProgress == null) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'นับถอยหลังรอบ 30 วัน',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withValues(alpha: 0.85),
                                  ),
                                ),
                                Text(
                                  '${(nextProgress * 100).toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: nextProgress,
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.22,
                                ),
                                valueColor: const AlwaysStoppedAnimation(
                                  Color(0xFF4ADE80),
                                ),
                                minHeight: 7,
                              ),
                            ),
                          ],
                        ),
                      );
                    }(),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Ongoing Activity (if any)
              if (_timeline?['current'] != null) ...[
                SectionCard(
                  title: 'กำลังทำอยู่',
                  child: _buildTimelineCard(
                    _timeline!['current'],
                    c.accent,
                    Icons.play_circle_fill_rounded,
                    isCurrent: true,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Previous Activities
              if (_timeline?['previous'] != null) ...[
                SectionCard(
                  title: 'กิจกรรมก่อนหน้า',
                  child: _buildTimelineCard(
                    _timeline!['previous'],
                    c.ink3,
                    Icons.history_rounded,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // All Activities
              SectionCard(
                title: 'กิจกรรมทั้งหมด',
                caption: '${_activities.length} กิจกรรม',
                child: _activities.isNotEmpty
                    ? Column(
                        children: [
                          for (var act in _activities)
                            _buildActivityTile(act, c),
                        ],
                      )
                    : Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            'ยังไม่มีกิจกรรม กด + เพื่อเพิ่ม',
                            style: TextStyle(color: c.ink3),
                          ),
                        ),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineCard(
    dynamic item,
    Color accent,
    IconData icon, {
    bool isCurrent = false,
  }) {
    final c = context.c;
    final ongoingProgress = isCurrent ? _calculateOngoingProgress(item) : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isCurrent
            ? c.accentSoft.withValues(alpha: 0.4)
            : accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accent.withValues(alpha: isCurrent ? 0.35 : 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['title']?.toString() ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: c.ink,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (item['startTime'] != null)
                          '${item['startTime']}'
                              .substring(
                                0,
                                ('${item['startTime']}'.length >= 10
                                    ? 10
                                    : '${item['startTime']}'.length),
                              )
                              .split('T')
                              .first,
                        if (item['location'] != null &&
                            item['location'].toString().isNotEmpty)
                          item['location'].toString(),
                      ].where((s) => s.isNotEmpty).join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: c.ink3),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (ongoingProgress != null) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'เวลาที่เหลือ (กำลังลดลง)',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: c.ink3,
                  ),
                ),
                Text(
                  '${(ongoingProgress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: ongoingProgress,
                backgroundColor: c.surface2,
                valueColor: AlwaysStoppedAnimation(accent),
                minHeight: 6,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActivityTile(dynamic act, AppColors c) {
    final timeType = _resolveTimeType(act);
    IconData typeIcon;
    Color typeColor;
    String typeLabel;

    switch (timeType) {
      case ActivityTimeType.timed:
        typeIcon = Icons.schedule_rounded;
        typeColor = c.accent;
        typeLabel = 'ระบุเวลา';
        break;
      case ActivityTimeType.allDay:
        typeIcon = Icons.today_rounded;
        typeColor = c.blue;
        typeLabel = 'ทั้งวัน';
        break;
      case ActivityTimeType.multiDay:
        typeIcon = Icons.date_range_rounded;
        typeColor = c.violet;
        typeLabel = 'ข้ามวัน';
        break;
      case ActivityTimeType.noDate:
        typeIcon = Icons.all_inclusive_rounded;
        typeColor = c.ink3;
        typeLabel = 'ไม่ระบุวัน';
        break;
      case ActivityTimeType.recurring:
        typeIcon = Icons.repeat_rounded;
        typeColor = c.amber;
        typeLabel = 'ทำซ้ำ';
        break;
    }

    String subtitle = typeLabel;
    if (timeType == ActivityTimeType.timed && act['startTime'] != null) {
      final st = DateTime.tryParse(act['startTime'].toString())?.toLocal();
      final et = act['endTime'] != null
          ? DateTime.tryParse(act['endTime'].toString())?.toLocal()
          : null;
      if (st != null) {
        subtitle = et != null
            ? '${_formatTime(st)} - ${_formatTime(et)}'
            : _formatTime(st);
      }
    } else if (timeType == ActivityTimeType.multiDay &&
        act['startTime'] != null) {
      final st = DateTime.tryParse(act['startTime'].toString())?.toLocal();
      final et = act['endTime'] != null
          ? DateTime.tryParse(act['endTime'].toString())?.toLocal()
          : null;
      if (st != null) {
        subtitle = et != null
            ? '${_formatDate(st)} - ${_formatDate(et)}'
            : _formatDate(st);
      }
    } else if (timeType == ActivityTimeType.recurring) {
      subtitle = _recurrenceName(act['recurrence']);
    }

    return GestureDetector(
      onTap: () => _openActivityModal(act),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.surface2,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(typeIcon, color: typeColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    act['title'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: c.ink,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: c.ink3),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.edit_outlined, size: 20, color: c.ink3),
              onPressed: () => _openActivityModal(act),
            ),
            IconButton(
              icon: Icon(
                Icons.delete_outline_rounded,
                size: 20,
                color: c.coral,
              ),
              onPressed: () async {
                await ActivityApiService.deleteActivity(act['id']);
                final notifId =
                    (act['id'].toString().hashCode).abs() % 2147483647;
                await NotificationService.cancelNotification(notifId);
                _loadActivities();
                DataEventService.notifyDataChanged();
              },
            ),
          ],
        ),
      ),
    );
  }
}
