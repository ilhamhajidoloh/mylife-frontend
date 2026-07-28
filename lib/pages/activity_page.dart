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
import 'package:flutter_local_notifications/flutter_local_notifications.dart' show DateTimeComponents;

enum ActivityTimeType {
  timed,
  allDay,
  multiDay,
  noDate,
  recurring,
}

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

  @override
  void initState() {
    super.initState();
    _loadActivities();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _remainingTime.inSeconds > 0) {
        setState(() {
          _remainingTime -= const Duration(seconds: 1);
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

    final cachedTimeline = await CacheService.get(userId, CacheService.activityTimeline);
    if (cachedTimeline != null) {
      _timeline = cachedTimeline;
      if (_timeline!['countdownSeconds'] != null) {
        final sec = (_timeline!['countdownSeconds'] as num?)?.toInt() ?? 0;
        _remainingTime = Duration(seconds: sec > 0 ? sec : 0);
      }
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
        _timeline = timeline;
        await CacheService.save(userId, CacheService.activityTimeline, timeline);
      }

      if (_timeline != null && _timeline!['countdownSeconds'] != null) {
        final sec = (_timeline!['countdownSeconds'] as num?)?.toInt() ?? 0;
        _remainingTime = Duration(seconds: sec > 0 ? sec : 0);
      }
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
  Future<void> _scheduleActivityNotification(dynamic act) async {
    try {
      final id = act['id'];
      if (id == null) return;
      final notifId = (id.toString().hashCode).abs() % 2147483647;

      if (act['isIndefinite'] == true || act['startTime'] == null) {
        await NotificationService.cancelNotification(notifId);
        return;
      }

      final start = DateTime.parse(act['startTime']).toLocal();
      final title = act['title'] ?? 'กิจกรรม';
      final location = act['location']?.toString() ?? '';

      if (act['isAllDay'] == true) {
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
      final recurrence = act['recurrence'] ?? 0;
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
        body: 'จะเริ่มเวลา ${_formatTime(start)} น.${location.isNotEmpty ? ' ที่ $location' : ''}',
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

  static const _thMonths = ['', 'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.', 'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'];

  String _formatDate(DateTime dt) {
    return '${dt.day} ${_thMonths[dt.month]} ${dt.year + 543}';
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    return '${_pad(local.hour)}:${_pad(local.minute)}';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  ActivityTimeType _resolveTimeType(dynamic act) {
    if (act['isIndefinite'] == true) return ActivityTimeType.noDate;
    if (act['isMultiDay'] == true) return ActivityTimeType.multiDay;
    if (act['isAllDay'] == true) return ActivityTimeType.allDay;
    final recurrence = act['recurrence'] ?? 0;
    if (recurrence != 0 && recurrence != null) return ActivityTimeType.recurring;
    return ActivityTimeType.timed;
  }

  void _openActivityModal([dynamic item]) {
    final isEdit = item != null;
    final titleController = TextEditingController(text: item?['title'] ?? '');
    final descController = TextEditingController(text: item?['description'] ?? '');
    final locationController = TextEditingController(text: item?['location'] ?? '');

    ActivityTimeType timeType = isEdit ? _resolveTimeType(item) : ActivityTimeType.timed;

    DateTime startDate = isEdit && item?['startTime'] != null
        ? (DateTime.tryParse(item!['startTime'])?.toLocal()) ?? DateTime.now().add(const Duration(hours: 1))
        : DateTime.now().add(const Duration(hours: 1));
    DateTime endDate = isEdit && item?['endTime'] != null
        ? (DateTime.tryParse(item!['endTime'])?.toLocal()) ?? DateTime.now().add(const Duration(hours: 2))
        : DateTime.now().add(const Duration(hours: 2));
    DateTime multiStartDate = startDate;
    DateTime multiEndDate = endDate;
    int recurrenceType = isEdit ? (item?['recurrence'] ?? 0) : 0;

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
              AppModalField(controller: titleController, label: 'ชื่อกิจกรรม', icon: Icons.event_rounded),
              const SizedBox(height: 12),
              AppModalField(controller: descController, label: 'รายละเอียด', icon: Icons.description_rounded),
              const SizedBox(height: 12),
              AppModalField(controller: locationController, label: 'สถานที่', icon: Icons.location_on_rounded),
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
                    decoration: BoxDecoration(color: cc.surface2, borderRadius: BorderRadius.circular(14)),
                    child: Column(
                      children: [
                        _datePickerRow('วันที่', startDate, cc, (dt) => setModalState(() {
                          startDate = DateTime(dt.year, dt.month, dt.day, startDate.hour, startDate.minute);
                        })),
                        const SizedBox(height: 10),
                        _timePickerRow('เวลาเริ่ม', startDate, cc, (dt) => setModalState(() => startDate = dt)),
                        const SizedBox(height: 10),
                        _timePickerRow('เวลาสิ้นสุด', endDate, cc, (dt) => setModalState(() => endDate = dt)),
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
                    decoration: BoxDecoration(color: cc.surface2, borderRadius: BorderRadius.circular(14)),
                    child: Column(
                      children: [
                        _datePickerRow('วันที่', startDate, cc, (dt) => setModalState(() {
                          startDate = DateTime(dt.year, dt.month, dt.day, 0, 0);
                          endDate = DateTime(dt.year, dt.month, dt.day, 23, 59);
                        })),
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
                        _dateTimePickerRow('เริ่มต้น', multiStartDate, cc, (dt) => setModalState(() => multiStartDate = dt)),
                        const SizedBox(height: 10),
                        _dateTimePickerRow('สิ้นสุด', multiEndDate, cc, (dt) => setModalState(() => multiEndDate = dt)),
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
                    decoration: BoxDecoration(color: cc.surface2, borderRadius: BorderRadius.circular(14)),
                    child: _datePickerRow('วันที่เริ่ม', startDate, cc, (dt) => setModalState(() {
                      startDate = DateTime(dt.year, dt.month, dt.day, 0, 0);
                    })),
                  ),
                ),
                const SizedBox(height: 16),
                AppModalSection(
                  title: 'ทำซ้ำ',
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: cc.surface2, borderRadius: BorderRadius.circular(14)),
                    child: Column(
                      children: [
                        _recurrenceOption('ทุกวัน', 1, recurrenceType, cc, (val) => setModalState(() => recurrenceType = val)),
                        _recurrenceOption('ทุกสัปดาห์', 2, recurrenceType, cc, (val) => setModalState(() => recurrenceType = val)),
                        _recurrenceOption('ทุกเดือน', 3, recurrenceType, cc, (val) => setModalState(() => recurrenceType = val)),
                        _recurrenceOption('ทุกปี', 4, recurrenceType, cc, (val) => setModalState(() => recurrenceType = val)),
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
                        final notifId = (item['id'].toString().hashCode).abs() % 2147483647;
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
                        child: Icon(Icons.delete_outline_rounded, color: cc.coral, size: 20),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(child: AppModalButton(label: 'ยกเลิก', onPressed: () => Navigator.pop(context), isPrimary: false)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppModalButton(
                      label: 'บันทึก',
                      onPressed: () async {
                        if (titleController.text.trim().isEmpty) return;
                        final userId = await UserSession.getUserId();
                        final isAllDay = timeType == ActivityTimeType.allDay;
                        final isMultiDay = timeType == ActivityTimeType.multiDay;
                        final isIndefinite = timeType == ActivityTimeType.noDate;
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
                            isAllDay ? 'ไม่ทำซ้ำ' : _recurrenceName(recurrenceType),
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
                            isAllDay ? 'ไม่ทำซ้ำ' : _recurrenceName(recurrenceType),
                            startTime: finalStart,
                            endTime: finalEnd,
                          );
                        }
                        if (saved != null) await _scheduleActivityNotification(saved);
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

  String _recurrenceName(int type) {
    switch (type) {
      case 1: return 'ทุกวัน';
      case 2: return 'ทุกสัปดาห์';
      case 3: return 'ทุกเดือน';
      case 4: return 'ทุกปี';
      default: return 'ไม่ทำซ้ำ';
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
                color: selected ? c.accent.withValues(alpha: 0.15) : c.border.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: selected ? c.accent : c.ink3),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: c.ink)),
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
                border: Border.all(color: selected ? c.accent : c.border, width: 2),
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

  Widget _datePickerRow(String label, DateTime current, AppColors c, ValueChanged<DateTime> onChanged) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: current,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: c.accent)),
            child: child!,
          ),
        );
        if (picked != null) {
          onChanged(DateTime(picked.year, picked.month, picked.day, current.hour, current.minute));
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
            Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: c.ink2)),
            const Spacer(),
            Flexible(
              child: Text(_formatDate(current),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(fontWeight: FontWeight.w700, color: c.accent, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timePickerRow(String label, DateTime current, AppColors c, ValueChanged<DateTime> onChanged) {
    return GestureDetector(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(current),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: c.accent)),
            child: child!,
          ),
        );
        if (picked != null) {
          onChanged(DateTime(current.year, current.month, current.day, picked.hour, picked.minute));
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
            Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: c.ink2)),
            const Spacer(),
            Flexible(
              child: Text(_formatTime(current),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(fontWeight: FontWeight.w700, color: c.accent, fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateTimePickerRow(String label, DateTime current, AppColors c, ValueChanged<DateTime> onChanged) {
    return GestureDetector(
      onTap: () async {
        final pickedDate = await showDatePicker(
          context: context,
          initialDate: current,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: c.accent)),
            child: child!,
          ),
        );
        if (pickedDate != null && mounted) {
          final pickedTime = await showTimePicker(
            context: context,
            initialTime: TimeOfDay.fromDateTime(current),
            builder: (ctx, child) => Theme(
              data: Theme.of(ctx).copyWith(colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: c.accent)),
              child: child!,
            ),
          );
          if (pickedTime != null) {
            onChanged(DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute));
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
            Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: c.ink2)),
            const Spacer(),
            Flexible(
              child: Text(
                '${_formatDate(current)} ${_formatTime(current)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: TextStyle(fontWeight: FontWeight.w700, color: c.accent, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recurrenceOption(String label, int value, int current, AppColors c, ValueChanged<int> onChanged) {
    final selected = value == current;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? c.accentSoft.withValues(alpha: 0.4) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? c.accent : c.border.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              size: 20,
              color: selected ? c.accent : c.ink3,
            ),
            const SizedBox(width: 10),
            Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: c.ink)),
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
            BoxShadow(color: c.accent.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () => _openActivityModal(),
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text('เพิ่มกิจกรรม', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadActivities,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
          children: [
            const PageHeader(title: 'กิจกรรม', subtitle: 'จัดการกิจกรรมและนับเวลาถอยหลัง'),
            const SizedBox(height: 16),

            if (_isLoading) ...[
              ValueListenableBuilder<bool>(
                valueListenable: ApiClient.isConnectingLong,
                builder: (context, isLong, child) {
                  return ServerConnectingWidget(
                    message: isLong ? 'กำลังปลุกเซิร์ฟเวอร์...' : 'กำลังดึงกิจกรรม...',
                    subMessage: isLong
                        ? 'เซิร์ฟเวอร์กำลังเริ่มต้นทำงาน โปรดรอสักครู่...'
                        : 'กำลังดึงข้อมูลกิจกรรมและกำหนดการของคุณ...',
                  );
                },
              ),
              const SizedBox(height: 16),
              const SkeletonCard(height: 140, borderRadius: 20),
            ]
            else ...[
              // Countdown Hero Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: c.heroGradient,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: c.accent.withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 8)),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.timer_outlined, color: Colors.white, size: 16),
                          const SizedBox(width: 6),
                          Text('กิจกรรมถัดไป', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.9))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _formatDuration(_remainingTime),
                      style: const TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _timeline?['next']?['title'] ?? 'ไม่มีกิจกรรมถัดไป',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    if (_timeline?['next']?['location'] != null && (_timeline!['next']['location'] as String).isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _timeline!['next']['location'],
                          style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.8)),
                        ),
                      ),
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
                          child: Text('ยังไม่มีกิจกรรม กด + เพื่อเพิ่ม', style: TextStyle(color: c.ink3)),
                        ),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineCard(dynamic item, Color accent, IconData icon) {
    final c = context.c;
    return Container(
      margin: const EdgeInsets.only(bottom: 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
      ),
      child: Row(
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
                Text(item['title'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w700, color: c.ink, fontSize: 14)),
                const SizedBox(height: 2),
                Text(
                  [
                    if (item['startTime'] != null) '${item['startTime']}'.substring(0, 10).split('T').first,
                    if (item['location'] != null && (item['location'] as String).isNotEmpty) item['location'],
                  ].where((s) => s != null && s.isNotEmpty).join(' • '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: c.ink3),
                ),
              ],
            ),
          ),
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
      subtitle = '${_formatTime(DateTime.parse(act['startTime']).toLocal())} - ${_formatTime(DateTime.parse(act['endTime']).toLocal())}';
    } else if (timeType == ActivityTimeType.multiDay && act['startTime'] != null) {
      subtitle = '${_formatDate(DateTime.parse(act['startTime']).toLocal())} - ${_formatDate(DateTime.parse(act['endTime']).toLocal())}';
    } else if (timeType == ActivityTimeType.recurring) {
      subtitle = _recurrenceName(act['recurrence'] ?? 0);
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
                  Text(act['title'] ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w700, color: c.ink, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.ink3)),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.edit_outlined, size: 20, color: c.ink3),
              onPressed: () => _openActivityModal(act),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline_rounded, size: 20, color: c.coral),
              onPressed: () async {
                await ActivityApiService.deleteActivity(act['id']);
                final notifId = (act['id'].toString().hashCode).abs() % 2147483647;
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
