import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/blocks.dart';
import '../services/api_client.dart';
import '../services/api_services.dart';
import '../services/user_session.dart';
import '../services/cache_service.dart';
import '../services/logger.dart';
import '../services/notification_service.dart';
import '../services/data_event_service.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  bool _isLoading = true;
  String _termName = 'ยังไม่ได้ตั้งค่าภาคเรียน';
  String? _termId;
  DateTime _termStartDate = DateTime.now();
  DateTime _termEndDate = DateTime.now().add(const Duration(days: 120));

  int _selectedDay = DateTime.now().weekday; // 1=Mon..7=Sun
  List<dynamic> _academicTerms = [];
  int _selectedTermIndex = 0;

  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadScheduleData();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadScheduleData() async {
    final userId = await UserSession.getUserId();

    // 1. โหลดข้อมูลจาก Cache ก่อนทันที
    final cached = await CacheService.get(userId, CacheService.scheduleTerms);
    if (cached != null && cached is List && cached.isNotEmpty) {
      _academicTerms = cached;
      _selectedTermIndex = _findDefaultTermIndex(cached);
      _updateActiveTermData();
      await _rescheduleAllCourseNotifications();
      if (mounted) setState(() => _isLoading = false);
    } else {
      if (mounted) setState(() => _isLoading = true);
    }

    try {
      final terms = await ScheduleApiService.getTerms(userId);
      if (terms != null && terms is List && terms.isNotEmpty) {
        _academicTerms = terms;
        _selectedTermIndex = _findDefaultTermIndex(terms);
        _updateActiveTermData();
        await CacheService.save(userId, CacheService.scheduleTerms, terms);
      }
      await _rescheduleAllCourseNotifications();
    } catch (e, st) {
      Logger.catchBlock('SchedulePage', 'loadScheduleData', e, st);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int _findDefaultTermIndex(List<dynamic> terms) {
    if (terms.isEmpty) return 0;
    final now = DateTime.now();
    final todayOnly = DateTime(now.year, now.month, now.day);

    // 1. ค้นหาเทอมที่วันที่ปัจจุบันอยู่ในช่วง [StartDate..EndDate]
    for (int i = 0; i < terms.length; i++) {
      final t = terms[i];
      final rawStart = t['startDate'] ?? t['StartDate'];
      final rawEnd = t['endDate'] ?? t['EndDate'];
      DateTime? sDate = rawStart != null ? DateTime.tryParse(rawStart.toString()) : null;
      DateTime? eDate = rawEnd != null ? DateTime.tryParse(rawEnd.toString()) : null;

      if (sDate != null && eDate != null) {
        final sOnly = DateTime(sDate.year, sDate.month, sDate.day);
        final eOnly = DateTime(eDate.year, eDate.month, eDate.day, 23, 59, 59);
        if (!now.isBefore(sOnly) && !now.isAfter(eOnly)) {
          return i;
        }
      }
    }

    // 2. หากไม่มีเทอมที่ตรงกับช่วงวันที่ปัจจุบันพอดี ให้หาเทอมที่ใกล้วันปัจจุบันมากที่สุด
    int closestIndex = 0;
    int minDiffDays = 999999;
    for (int i = 0; i < terms.length; i++) {
      final t = terms[i];
      final rawStart = t['startDate'] ?? t['StartDate'];
      DateTime? sDate = rawStart != null ? DateTime.tryParse(rawStart.toString()) : null;
      if (sDate != null) {
        final sOnly = DateTime(sDate.year, sDate.month, sDate.day);
        final diff = (sOnly.difference(todayOnly).inDays).abs();
        if (diff < minDiffDays) {
          minDiffDays = diff;
          closestIndex = i;
        }
      }
    }

    return closestIndex;
  }

  void _updateActiveTermData() {
    if (_academicTerms.isEmpty) {
      _termId = null;
      _termName = 'ยังไม่ได้ตั้งค่าภาคเรียน';
      _termStartDate = DateTime.now();
      _termEndDate = DateTime.now().add(const Duration(days: 120));
      return;
    }
    if (_selectedTermIndex >= _academicTerms.length) {
      _selectedTermIndex = 0;
    }
    final currentTerm = _academicTerms[_selectedTermIndex];
    _termId = (currentTerm['id'] ?? currentTerm['Id'])?.toString();
    _termName = (currentTerm['termName'] ?? currentTerm['TermName'])?.toString() ?? 'ภาคเรียน';
    final rawStart = currentTerm['startDate'] ?? currentTerm['StartDate'];
    final rawEnd = currentTerm['endDate'] ?? currentTerm['EndDate'];
    if (rawStart != null) {
      _termStartDate = DateTime.tryParse(rawStart.toString()) ?? _termStartDate;
    }
    if (rawEnd != null) {
      _termEndDate = DateTime.tryParse(rawEnd.toString()) ?? _termEndDate;
    }
  }

  /// ตั้งเวลาแจ้งเตือนสำหรับวิชาเรียนทั้งหมดที่โหลดมาใหม่
  Future<void> _rescheduleAllCourseNotifications() async {
    if (_academicTerms.isEmpty || _selectedTermIndex >= _academicTerms.length) return;
    try {
      final courses = (_academicTerms[_selectedTermIndex]['courses'] as List?) ?? [];
      for (final course in courses) {
        final id = course['id'];
        final name = course['courseName'] ?? course['courseCode'] ?? '';
        final room = course['room']?.toString() ?? '';
        final startTimeStr = course['startTime']?.toString() ?? '';

        final rawDayVal = course['dayOfWeek'];
        int rawDay = 1;
        if (rawDayVal is int) {
          rawDay = rawDayVal;
        } else if (rawDayVal != null) {
          final str = rawDayVal.toString().toLowerCase().trim();
          final parsed = int.tryParse(str);
          if (parsed != null) {
            rawDay = parsed;
          } else if (str.contains('sun')) {
            rawDay = 0;
          } else if (str.contains('mon')) {
            rawDay = 1;
          } else if (str.contains('tue')) {
            rawDay = 2;
          } else if (str.contains('wed')) {
            rawDay = 3;
          } else if (str.contains('thu')) {
            rawDay = 4;
          } else if (str.contains('fri')) {
            rawDay = 5;
          } else if (str.contains('sat')) {
            rawDay = 6;
          }
        }

        final dartDay = (rawDay == 0) ? 7 : rawDay;

        if (id == null || name.toString().trim().isEmpty || startTimeStr.toString().trim().isEmpty) continue;

        final timeParts = startTimeStr.toString().split(':');
        final hour = int.tryParse(timeParts[0]) ?? 0;
        final minute = timeParts.length > 1 ? (int.tryParse(timeParts[1]) ?? 0) : 0;

        final notifId = (id.toString().hashCode).abs() % 2147483647;
        await NotificationService.scheduleWeeklyCourseNotification(
          id: notifId,
          title: '🎓 เตรียมตัวเรียนวิชา $name',
          body: 'จะเริ่มเรียนเวลา $startTimeStr น.${room.isNotEmpty ? " (ห้อง $room)" : ""}',
          dayOfWeek: dartDay,
          hour: hour,
          minute: minute,
          advanceMinutes: 15,
        );
      }
      Logger.info('SchedulePage', 'Rescheduled ${courses.length} course notifications');
    } catch (e, st) {
      Logger.catchBlock('SchedulePage', 'rescheduleAllCourseNotifications', e, st);
    }
  }

  Future<void> _testNotification() async {
    await NotificationService.showInstantNotification(
      id: 9999,
      title: '🔔 ทดสอบระบบแจ้งเตือน',
      body: 'ระบบแจ้งเตือนของ MyLife ทำงานเรียบร้อย ✅ คุณจะได้รับแจ้งเตือนค่าเรียน 15 นาทีก่อนเริ่มเรียนทุกครั้ง',
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('ส่งการแจ้งเตือนทดสอบแล้ว! เช็คแถบอัปเดงตั้งค่า ↓'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  List<dynamic> get _selectedDayClasses {
    if (_academicTerms.isEmpty || _selectedTermIndex >= _academicTerms.length) return [];
    final activeTerm = _academicTerms[_selectedTermIndex];
    final courses = (activeTerm['courses'] ?? activeTerm['Courses']) as List?;
    if (courses == null) return [];
    return courses.where((c) {
      final rawDayVal = c['dayOfWeek'] ?? c['DayOfWeek'];
      int rawDay = 1;
      if (rawDayVal is int) {
        rawDay = rawDayVal;
      } else if (rawDayVal != null) {
        final str = rawDayVal.toString().toLowerCase().trim();
        final parsed = int.tryParse(str);
        if (parsed != null) {
          rawDay = parsed;
        } else if (str.contains('sun')) {
          rawDay = 0;
        } else if (str.contains('mon')) {
          rawDay = 1;
        } else if (str.contains('tue')) {
          rawDay = 2;
        } else if (str.contains('wed')) {
          rawDay = 3;
        } else if (str.contains('thu')) {
          rawDay = 4;
        } else if (str.contains('fri')) {
          rawDay = 5;
        } else if (str.contains('sat')) {
          rawDay = 6;
        }
      }

      final dartDay = (rawDay == 0) ? 7 : rawDay;
      return dartDay == _selectedDay;
    }).toList()
      ..sort((a, b) {
        final aStart = (a['startTime'] ?? a['StartTime'] ?? '').toString();
        final bStart = (b['startTime'] ?? b['StartTime'] ?? '').toString();
        return aStart.compareTo(bStart);
      });
  }

  String _dayName(int day) => ['', 'จันทร์', 'อังคาร', 'พุธ', 'พฤหัสบดี', 'ศุกร์', 'เสาร์', 'อาทิตย์'][day];

  String _dayShort(int day) => ['', 'จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส', 'อา'][day];

  String _formatCountdown(Duration d) {
    if (d.inSeconds <= 0) return '';
    if (d.inHours >= 1) {
      return '${d.inHours} ชม. ${d.inMinutes.remainder(60)} นาที';
    }
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    if (m > 0) return '$m นาที ${s.toString().padLeft(2, '0')} วิ';
    return '$s วินาที';
  }

  Duration _calcCountdownFor({required int endHour, required int endMin}) {
    final end = DateTime(_now.year, _now.month, _now.day, endHour, endMin);
    final diff = end.difference(_now);
    return diff.isNegative ? Duration.zero : diff;
  }

  Duration _calcCountdownToStart({required int startHour, required int startMin}) {
    final start = DateTime(_now.year, _now.month, _now.day, startHour, startMin);
    final diff = start.difference(_now);
    return diff.isNegative ? Duration.zero : diff;
  }

  void _openAcademicTermModal() {
    _openTermManagementModal();
  }

  void _openTermManagementModal() {
    showAppBottomSheet(
      context,
      title: 'จัดการภาคเรียน',
      subtitle: 'เลือกหรือเพิ่ม/แก้ไขภาคเรียนทั้งหมด',
      child: StatefulBuilder(
        builder: (context, setModalState) {
          final cc = context.c;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  _openAddOrEditTermModal();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    gradient: cc.accentGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 6),
                      Text('เพิ่มภาคเรียนใหม่',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_academicTerms.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(child: Text('ยังไม่มีภาคเรียนในระบบ', style: TextStyle(color: cc.ink3))),
                )
              else
                Column(
                  children: List.generate(_academicTerms.length, (i) {
                    final term = _academicTerms[i];
                    final isSelected = _selectedTermIndex == i;
                    final courseCount = (term['courses'] as List?)?.length ?? 0;
                    DateTime? sDate = term['startDate'] != null ? DateTime.tryParse(term['startDate']) : null;
                    DateTime? eDate = term['endDate'] != null ? DateTime.tryParse(term['endDate']) : null;
                    String dateStr = '';
                    if (sDate != null && eDate != null) {
                      dateStr = '${sDate.day}/${sDate.month}/${sDate.year} - ${eDate.day}/${eDate.month}/${eDate.year}';
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isSelected ? cc.accentSoft.withValues(alpha: 0.5) : cc.surface2,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? cc.accent : cc.border.withValues(alpha: 0.5),
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: isSelected ? cc.accent : cc.surface,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.school_rounded, color: isSelected ? Colors.white : cc.accent, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        term['termName'] ?? 'ภาคเรียน',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: cc.ink),
                                      ),
                                    ),
                                    if (isSelected)
                                      Pill('ใช้งานอยู่', fg: cc.accent, bg: cc.accentSoft),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$dateStr • $courseCount วิชา',
                                  style: TextStyle(fontSize: 12, color: cc.ink3),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!isSelected)
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedTermIndex = i;
                                      _updateActiveTermData();
                                    });
                                    _rescheduleAllCourseNotifications();
                                    Navigator.pop(context);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    margin: const EdgeInsets.only(right: 6),
                                    decoration: BoxDecoration(
                                      color: cc.accent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text('เลือก', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.pop(context);
                                  _openAddOrEditTermModal(term);
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: cc.surface, borderRadius: BorderRadius.circular(10)),
                                  child: Icon(Icons.edit_rounded, size: 18, color: cc.ink2),
                                ),
                              ),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () {
                                  Navigator.pop(context);
                                  _confirmDeleteTerm(term);
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: cc.coralSoft, borderRadius: BorderRadius.circular(10)),
                                  child: Icon(Icons.delete_outline_rounded, size: 18, color: cc.coral),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                ),
            ],
          );
        },
      ),
    );
  }

  void _openAddOrEditTermModal([dynamic item]) {
    final isEdit = item != null;
    final termController = TextEditingController(text: item?['termName'] ?? '');
    DateTime startDate = isEdit && item['startDate'] != null
        ? (DateTime.tryParse(item['startDate']) ?? DateTime.now())
        : DateTime.now();
    DateTime endDate = isEdit && item['endDate'] != null
        ? (DateTime.tryParse(item['endDate']) ?? DateTime.now().add(const Duration(days: 120)))
        : DateTime.now().add(const Duration(days: 120));

    showAppDialog(
      context,
      title: isEdit ? 'แก้ไขภาคเรียน' : 'เพิ่มภาคเรียนใหม่',
      subtitle: 'กำหนดชื่อและวันที่ภาคเรียน',
      content: StatefulBuilder(
        builder: (context, setModalState) {
          final cc = context.c;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppModalField(controller: termController, label: 'ชื่อภาคเรียน เช่น ภาคเรียน 1/2567', icon: Icons.school_rounded),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: startDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                    builder: (ctx, child) => Theme(
                      data: Theme.of(ctx).copyWith(colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: cc.accent)),
                      child: child!,
                    ),
                  );
                  if (picked != null) setModalState(() => startDate = picked);
                },
                child: _dateDisplayRow('วันเริ่ม', startDate, cc.accent, cc),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: endDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                    builder: (ctx, child) => Theme(
                      data: Theme.of(ctx).copyWith(colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: cc.accent)),
                      child: child!,
                    ),
                  );
                  if (picked != null) setModalState(() => endDate = picked);
                },
                child: _dateDisplayRow('วันสิ้นสุด', endDate, cc.coral, cc),
              ),
            ],
          );
        },
      ),
      actions: [
        AppModalButton(label: 'ยกเลิก', onPressed: () => Navigator.pop(context), isPrimary: false),
        AppModalButton(
          label: 'บันทึก',
          onPressed: () async {
            if (termController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('กรุณากรอกชื่อภาคเรียน')),
              );
              return;
            }
            final userId = await UserSession.getUserId();
            if (isEdit && item?['id'] != null) {
              await ScheduleApiService.updateTerm(item['id'].toString(), userId, termController.text.trim(), startDate, endDate);
            } else {
              await ScheduleApiService.addTerm(userId, termController.text.trim(), startDate, endDate);
            }
            if (mounted) Navigator.pop(context);
            await _loadScheduleData();
            DataEventService.notifyDataChanged();
          },
        ),
      ],
    );
  }

  void _confirmDeleteTerm(dynamic item) {
    if (item == null || item['id'] == null) return;
    final termName = item['termName'] ?? 'ภาคเรียนนี้';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบภาคเรียน'),
        content: Text('คุณต้องการลบ "$termName" หรือไม่?\nวิชาเรียนทั้งหมดในภาคเรียนนี้จะถูกลบไปด้วย'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ScheduleApiService.deleteTerm(item['id'].toString());
              await _loadScheduleData();
              DataEventService.notifyDataChanged();
            },
            child: const Text('ลบ', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _dateDisplayRow(String label, DateTime date, Color accent, AppColors c) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_today_rounded, size: 18, color: accent),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: c.ink))),
          Text('${date.day}/${date.month}/${date.year}', style: TextStyle(fontWeight: FontWeight.w700, color: c.ink2)),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right_rounded, size: 18, color: c.ink3),
        ],
      ),
    );
  }

  void _openCourseModal([dynamic item]) {
    final isEdit = item != null;
    final codeController = TextEditingController(text: item?['courseCode'] ?? '');
    final nameController = TextEditingController(text: item?['courseName'] ?? '');
    final roomController = TextEditingController(text: item?['room'] ?? '');
    final instructorController = TextEditingController(text: item?['instructor'] ?? '');
    int rawDay = item?['dayOfWeek'] ?? _selectedDay;
    int dayOfWeek = (rawDay == 0) ? 7 : rawDay;
    TimeOfDay startTime = _parseTime(item?['startTime'] ?? '09:00');
    TimeOfDay endTime = _parseTime(item?['endTime'] ?? '10:00');
    String targetTermId = (item?['termId'] ?? item?['academicTermId'] ?? _termId ?? (_academicTerms.isNotEmpty ? _academicTerms[_selectedTermIndex]['id'] : '')).toString();

    showAppBottomSheet(
      context,
      title: isEdit ? 'แก้ไขวิชาเรียน' : 'เพิ่มวิชาใหม่',
      child: StatefulBuilder(
        builder: (context, setModalState) {
          final cc = context.c;
          final activeTermObj = _academicTerms.firstWhere((t) => t['id'].toString() == targetTermId, orElse: () => null);
          final activeTermName = activeTermObj != null ? (activeTermObj['termName'] ?? 'ภาคเรียน') : _termName;

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Term Badge / Selector
              if (_academicTerms.length > 1)
                AppModalSection(
                  title: 'ภาคเรียนที่จะบันทึกวิชาลงไป',
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: cc.accentSoft.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cc.accent.withValues(alpha: 0.3)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: targetTermId.isNotEmpty && _academicTerms.any((t) => t['id'].toString() == targetTermId)
                            ? targetTermId
                            : null,
                        isExpanded: true,
                        icon: Icon(Icons.arrow_drop_down_rounded, color: cc.accent),
                        items: _academicTerms.map<DropdownMenuItem<String>>((t) {
                          final id = t['id'].toString();
                          final name = t['termName'] ?? 'ภาคเรียน';
                          return DropdownMenuItem<String>(
                            value: id,
                            child: Row(
                              children: [
                                Icon(Icons.school_rounded, size: 16, color: cc.accent),
                                const SizedBox(width: 8),
                                Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: cc.ink, fontSize: 13.5)),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setModalState(() => targetTermId = val);
                        },
                      ),
                    ),
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: cc.accentSoft.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cc.accent.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.school_rounded, size: 18, color: cc.accent),
                      const SizedBox(width: 8),
                      Text('บันทึกลงภาคเรียน: $activeTermName', style: TextStyle(fontWeight: FontWeight.w700, color: cc.accent, fontSize: 13)),
                    ],
                  ),
                ),
              const SizedBox(height: 14),

              AppModalField(controller: codeController, label: 'รหัสวิชา', icon: Icons.tag_rounded),
              const SizedBox(height: 12),
              AppModalField(controller: nameController, label: 'ชื่อวิชา', icon: Icons.book_rounded),
              const SizedBox(height: 12),
              AppModalField(controller: roomController, label: 'ห้องเรียน', icon: Icons.meeting_room_rounded),
              const SizedBox(height: 12),
              AppModalField(controller: instructorController, label: 'ผู้สอน', icon: Icons.person_rounded),
              const SizedBox(height: 12),

              // Day selector chips
              AppModalSection(
                title: 'วันในสัปดาห์',
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: List.generate(7, (i) {
                    final day = i + 1;
                    final selected = dayOfWeek == day;
                    return GestureDetector(
                      onTap: () => setModalState(() => dayOfWeek = day),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected ? cc.accent : cc.surface2,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: selected ? cc.accent : cc.border),
                        ),
                        child: Text(_dayShort(day), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: selected ? Colors.white : cc.ink3)),
                      ),
                    );
                  }),
                ),
              ),

              const SizedBox(height: 16),

              // Time pickers
              AppModalSection(
                title: 'เวลาเรียน',
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: cc.surface2, borderRadius: BorderRadius.circular(14)),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: startTime,
                            builder: (ctx, child) => Theme(
                              data: Theme.of(ctx).copyWith(colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: cc.accent)),
                              child: child!,
                            ),
                          );
                          if (picked != null) setModalState(() => startTime = picked);
                        },
                        child: _timeRow('เวลาเริ่ม', startTime, cc),
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: endTime,
                            builder: (ctx, child) => Theme(
                              data: Theme.of(ctx).copyWith(colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: cc.accent)),
                              child: child!,
                            ),
                          );
                          if (picked != null) setModalState(() => endTime = picked);
                        },
                        child: _timeRow('เวลาสิ้นสุด', endTime, cc),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
              Row(
                children: [
                  if (isEdit) ...[
                    GestureDetector(
                      onTap: () => _confirmDelete(item, context),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: cc.coralSoft, borderRadius: BorderRadius.circular(12)),
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
                        final code = codeController.text.trim();
                        final name = nameController.text.trim();
                        // บังคับมีอย่างใดอย่างหนึ่ง: รหัสวิชา หรือ ชื่อวิชา
                        if (code.isEmpty && name.isEmpty) return;

                        final finalCode = code.isEmpty ? name : code;
                        final finalName = name.isEmpty ? code : name;

                        final userId = await UserSession.getUserId();
                        if (_termId == null || _termId!.isEmpty) {
                          final defaultTermName = (_termName == 'ยังไม่ได้ตั้งค่าภาคเรียน' || _termName.isEmpty) ? 'ภาคเรียนที่ 1' : _termName;
                          final termRes = await ScheduleApiService.addTerm(userId, defaultTermName, _termStartDate, _termEndDate);
                          if (termRes != null) {
                            _termId = (termRes['id'] ?? termRes['Id'])?.toString();
                            _termName = defaultTermName;
                          }
                        }

                        final startStr = '${_pad(startTime.hour)}:${_pad(startTime.minute)}';
                        final endStr = '${_pad(endTime.hour)}:${_pad(endTime.minute)}';

                        final termIdToUse = targetTermId.isNotEmpty ? targetTermId : (_termId ?? '');

                        if (isEdit && item != null && item['id'] != null) {
                          await ScheduleApiService.updateCourse(
                            item['id'].toString(),
                            termIdToUse,
                            finalCode,
                            finalName,
                            roomController.text.trim(),
                            instructorController.text.trim(),
                            dayOfWeek,
                            startStr,
                            endStr,
                          );
                        } else {
                          await ScheduleApiService.addCourse(
                            termIdToUse,
                            finalCode,
                            finalName,
                            roomController.text.trim(),
                            instructorController.text.trim(),
                            dayOfWeek,
                            startStr,
                            endStr,
                          );
                        }

                        // ตั้งเวลาแจ้งเตือนล่วงหน้า 15 นาที ก่อนเข้าเรียนทุกสัปดาห์
                        final notifId = ((item?['id'] ?? finalName).hashCode).abs() % 2147483647;
                        await NotificationService.scheduleWeeklyCourseNotification(
                          id: notifId,
                          title: '🎓 เตรียมตัวเรียนวิชา $finalName',
                          body: 'จะเริ่มเรียนเวลา $startStr น. (ห้อง ${roomController.text.trim().isNotEmpty ? roomController.text.trim() : "-"})',
                          dayOfWeek: dayOfWeek,
                          hour: startTime.hour,
                          minute: startTime.minute,
                          advanceMinutes: 15,
                        );

                        if (context.mounted) Navigator.pop(context);
                        _loadScheduleData();
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

  void _confirmDelete(dynamic item, BuildContext parentContext) {
    final c = parentContext.c;
    showDialog(
      context: parentContext,
      builder: (ctx) => Dialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: c.coralSoft, borderRadius: BorderRadius.circular(16)),
                child: Icon(Icons.delete_outline_rounded, color: c.coral, size: 28),
              ),
              const SizedBox(height: 16),
              Text('ลบวิชานี้?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c.ink)),
              const SizedBox(height: 6),
              Text(
                'ต้องการลบ "${item['courseName'] ?? ''}" ออกจากรายการ',
                style: TextStyle(fontSize: 13, color: c.ink3),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: AppModalButton(label: 'ยกเลิก', onPressed: () => Navigator.pop(ctx), isPrimary: false),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppModalButton(
                      label: 'ลบ',
                      isDestructive: true,
                      onPressed: () async {
                        if (item['id'] != null) {
                          final notifId = (item['id'].toString().hashCode).abs() % 2147483647;
                          await NotificationService.cancelNotification(notifId);
                        }
                        await ScheduleApiService.deleteCourse(item['id']);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (parentContext.mounted) Navigator.pop(parentContext);
                        _loadScheduleData();
                        DataEventService.notifyDataChanged();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  TimeOfDay _parseTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts.length > 1 ? parts[1] : '0'));
    } catch (_) {
      return const TimeOfDay(hour: 9, minute: 0);
    }
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  Widget _timeRow(String label, TimeOfDay time, AppColors c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.border.withValues(alpha: 0.5))),
      child: Row(
        children: [
          Icon(Icons.access_time_rounded, size: 18, color: c.accent),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: c.ink2)),
          const Spacer(),
          Text('${_pad(time.hour)}:${_pad(time.minute)}', style: TextStyle(fontWeight: FontWeight.w700, color: c.accent, fontSize: 15)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final dayClasses = _selectedDayClasses;

    return Scaffold(
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: c.accentGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: c.accent.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: FloatingActionButton.extended(
          onPressed: () => _openCourseModal(),
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text('เพิ่มวิชา', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadScheduleData,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ตารางเรียน', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.7, color: c.ink)),
                      const SizedBox(height: 4),
                      Text(_termName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: c.ink3)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _openAcademicTermModal,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        Icon(Icons.settings_rounded, size: 16, color: c.accent),
                        const SizedBox(width: 4),
                        Text('ตั้งค่าเทอม', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.accent)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _testNotification,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: c.good.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: c.good.withValues(alpha: 0.3)),
                    ),
                    child: Icon(Icons.notifications_active_rounded, size: 18, color: c.good),
                  ),
                ),
              ],
            ),

            // Term Selector Chips
            if (_academicTerms.length > 1) ...[
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (int i = 0; i < _academicTerms.length; i++) ...[
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedTermIndex = i;
                            _updateActiveTermData();
                          });
                          _rescheduleAllCourseNotifications();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: _selectedTermIndex == i ? c.accent : c.surface2,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _selectedTermIndex == i ? c.accent : c.border.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.school_rounded,
                                size: 14,
                                color: _selectedTermIndex == i ? Colors.white : c.ink3,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _academicTerms[i]['termName'] ?? 'ภาคเรียน',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: _selectedTermIndex == i ? Colors.white : c.ink2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    GestureDetector(
                      onTap: () => _openAddOrEditTermModal(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: c.accentSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.add_rounded, size: 16, color: c.accent),
                            const SizedBox(width: 4),
                            Text('เพิ่มเทอม', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: c.accent)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Term info bar
            if (_academicTerms.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: c.accentSoft.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.accent.withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.school_rounded, size: 16, color: c.accent),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '${_termStartDate.day}/${_termStartDate.month}/${_termStartDate.year} — ${_termEndDate.day}/${_termEndDate.month}/${_termEndDate.year}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: c.accent),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(_academicTerms.isNotEmpty && _selectedTermIndex < _academicTerms.length ? ((_academicTerms[_selectedTermIndex]['courses'] ?? _academicTerms[_selectedTermIndex]['Courses']) as List?)?.length : 0) ?? 0} วิชา',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.ink3),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            if (_isLoading) ...[
              ValueListenableBuilder<bool>(
                valueListenable: ApiClient.isConnectingLong,
                builder: (context, isLong, child) {
                  return ServerConnectingWidget(
                    message: isLong ? 'กำลังปลุกเซิร์ฟเวอร์...' : 'กำลังดึงตารางเรียน...',
                    subMessage: isLong
                        ? 'เซิร์ฟเวอร์กำลังสตาร์ทขึ้นมาใหม่ โปรดรอสักครู่...'
                        : 'กำลังดึงข้อมูลรายวิชาและภาคการเรียนของคุณ...',
                  );
                },
              ),
              const SizedBox(height: 16),
              const SkeletonCard(height: 140, borderRadius: 20),
            ]
            else ...[
              // Day selector chips
              SectionCard(
                title: 'เลือกวัน',
                caption: 'เลือกวันเพื่อดูตารางเรียน',
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(7, (i) {
                      final day = i + 1;
                      final selected = _selectedDay == day;
                      final isToday = day == DateTime.now().weekday;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedDay = day),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 52,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: selected ? c.accent : (isToday ? c.accentSoft : c.surface2),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: selected ? c.accent : (isToday ? c.accent.withValues(alpha: 0.3) : c.border),
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(_dayShort(day), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: selected ? Colors.white : c.ink3)),
                                const SizedBox(height: 4),
                                if (isToday)
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(color: selected ? Colors.white : c.accent, shape: BoxShape.circle),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Timeline for selected day
              SectionCard(
                title: '${_dayName(_selectedDay)}นี้',
                caption: dayClasses.isNotEmpty ? '${dayClasses.length} วิชา' : 'ว่าง',
                child: dayClasses.isNotEmpty
                    ? Column(
                        children: [
                          for (var i = 0; i < dayClasses.length; i++)
                            _buildClassTimelineTile(dayClasses[i], i, dayClasses.length, c),
                        ],
                      )
                    : Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.event_busy_rounded, size: 40, color: c.ink3.withValues(alpha: 0.4)),
                              const SizedBox(height: 8),
                              Text('ไม่มีวิชาเรียนวัน${_dayName(_selectedDay)}', style: TextStyle(color: c.ink3)),
                            ],
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 16),

              // Weekly timetable
              SectionCard(
                title: 'ตารางเรียนรายสัปดาห์',
                caption: 'ภาพรวมทั้งสัปดาห์',
                child: TimetableView(
                  courses: (_academicTerms.isNotEmpty && _selectedTermIndex < _academicTerms.length)
                      ? (_academicTerms[_selectedTermIndex]['courses'] as List? ?? [])
                      : [],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildClassTimelineTile(dynamic course, int index, int total, AppColors c) {
    final isLast = index == total - 1;
    final now = _now;
    final startTime = _parseTime(course['startTime'] ?? '09:00');
    final endTime = _parseTime(course['endTime'] ?? '10:00');
    final courseStart = DateTime(now.year, now.month, now.day, startTime.hour, startTime.minute);
    final courseEnd = DateTime(now.year, now.month, now.day, endTime.hour, endTime.minute);

    bool isCurrent = false;
    bool isPast = false;
    bool isNext = false;
    if (_selectedDay == now.weekday) {
      if (now.isAfter(courseStart) && now.isBefore(courseEnd)) {
        isCurrent = true;
      } else if (now.isAfter(courseEnd)) {
        isPast = true;
      } else if (!isPast && !isCurrent) {
        // Mark as "next" if this class starts at the earliest upcoming time
        // (supports multiple classes starting simultaneously)
        final upcomingClasses = _selectedDayClasses.where((cl) {
          final st = _parseTime(cl['startTime'] ?? '09:00');
          return DateTime(now.year, now.month, now.day, st.hour, st.minute).isAfter(now);
        }).toList();
        if (upcomingClasses.isNotEmpty) {
          final earliestStart = upcomingClasses.first['startTime'];
          if (course['startTime'] == earliestStart) {
            isNext = true;
          }
        }
      }
    }

    final color = isCurrent ? c.accent : (isPast ? c.ink3 : (isNext ? c.blue : c.blue));
    final bgColor = isCurrent
        ? c.accentSoft.withValues(alpha: 0.4)
        : (isPast
            ? c.surface2
            : (isNext ? c.blue.withValues(alpha: 0.1) : c.blue.withValues(alpha: 0.06)));

    // Compute countdown string
    String? countdownText;
    String? countdownLabel;
    if (isCurrent) {
      final remaining = _calcCountdownFor(endHour: endTime.hour, endMin: endTime.minute);
      if (remaining.inSeconds > 0) {
        countdownText = _formatCountdown(remaining);
        countdownLabel = 'เหลือ';
      }
    } else if (isNext) {
      final until = _calcCountdownToStart(startHour: startTime.hour, startMin: startTime.minute);
      if (until.inSeconds > 0) {
        countdownText = _formatCountdown(until);
        countdownLabel = 'อีก';
      }
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline rail
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: isCurrent ? Border.all(color: c.accent, width: 3) : null,
                    boxShadow: isCurrent ? [BoxShadow(color: c.accent.withValues(alpha: 0.4), blurRadius: 6)] : null,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      decoration: BoxDecoration(
                        color: isPast ? c.border : c.accent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Card
          Expanded(
            child: Container(
              margin: EdgeInsets.only(bottom: isLast ? 0 : 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(14),
                border: isCurrent ? Border.all(color: c.accent.withValues(alpha: 0.3)) : null,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                course['courseName'] ?? '',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: isPast ? c.ink3 : c.ink,
                                ),
                              ),
                            ),
                            if (isCurrent)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(8)),
                                child: const Text('กำลังเรียน', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                              ),
                            if (isNext)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: c.blue.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                                child: Text('ถัดไป', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: c.blue)),
                              ),
                            if (isPast)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(8)),
                                child: Text('แล้ว', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: c.ink3)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.access_time_rounded, size: 13, color: c.ink3),
                            const SizedBox(width: 4),
                            Text(
                              '${course['startTime'] ?? ''} - ${course['endTime'] ?? ''} น.',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.ink3),
                            ),
                            const SizedBox(width: 12),
                            Icon(Icons.meeting_room_rounded, size: 13, color: c.ink3),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                course['room'] ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.ink3),
                              ),
                            ),
                          ],
                        ),
                        if (course['instructor'] != null && (course['instructor'] as String).isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Icon(Icons.person_rounded, size: 13, color: c.ink3),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    course['instructor'],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.ink3),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (countdownText != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: color.withValues(alpha: 0.25)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.timer_rounded, size: 13, color: color),
                                  const SizedBox(width: 5),
                                  Text(
                                    '$countdownLabel $countdownText',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _openCourseModal(course),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(8)),
                      child: Icon(Icons.edit_rounded, size: 16, color: c.ink3),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
