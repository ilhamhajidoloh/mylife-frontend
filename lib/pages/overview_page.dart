import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/charts.dart';
import '../services/api_client.dart';
import '../services/api_services.dart';
import '../services/user_session.dart';
import '../services/cache_service.dart';
import '../services/logger.dart';
import '../services/data_event_service.dart';


class OverviewPage extends StatefulWidget {
  const OverviewPage({super.key});

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  bool _isLoading = true;
  String _userName = 'ผู้ใช้งาน';
  double _netBalance = 0.0;
  double _totalIncome = 0.0;
  double _totalExpense = 0.0;

  Map<String, dynamic>? _todayClasses;
  Map<String, dynamic>? _activityTimeline;
  Map<String, dynamic>? _todoDaily;
  List<dynamic> _urgentTasks = [];
  List<dynamic> _recurringExpenses = [];

  String _breakdownPeriod = 'monthly';
  List<dynamic> _breakdownData = [];
  int _breakdownYear = DateTime.now().year;
  int _breakdownMonth = DateTime.now().month;
  bool _isBreakdownLoading = true;

  late Timer _timer;
  Timer? _autoRefreshTimer;
  StreamSubscription<void>? _dataSubscription;

  Duration _nextEventCountdown = Duration.zero;
  Duration _currentClassRemaining = Duration.zero;
  Duration _nextClassCountdown = Duration.zero;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
    _loadBreakdown();

    // ฟังสัญญาณการเปลี่ยนแปลงข้อมูลเพื่ออัพเดตแบบ Real-time ทันที
    _dataSubscription = DataEventService.onDataChanged.listen((_) {
      if (mounted) {
        _fetchDashboardData(silent: true);
        _loadBreakdown();
      }
    });

    // ตั้งเวลาดึงข้อมูลอัตโนมัติเบื้องหลังทุกๆ 15 วินาที
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) _fetchDashboardData(silent: true);
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        if (_nextEventCountdown.inSeconds > 0) {
          _nextEventCountdown -= const Duration(seconds: 1);
        }
        _calcClassCountdowns();
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _autoRefreshTimer?.cancel();
    _dataSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchDashboardData({bool silent = false}) async {
    final userId = await UserSession.getUserId();
    final name = await UserSession.getUserName();
    _userName = name;

    // 1. โหลดข้อมูลจาก Cache ทันทีเพื่อให้แสดงผลได้ทันทีโดยไม่ต้องรอ API (Stale-While-Revalidate)
    if (!silent) {
      final cachedFinance = await CacheService.get(userId, CacheService.financeSummary);
      if (cachedFinance != null) {
        _netBalance = (cachedFinance['netBalance'] as num?)?.toDouble() ?? 0.0;
        _totalIncome = (cachedFinance['totalIncome'] as num?)?.toDouble() ?? 0.0;
        _totalExpense = (cachedFinance['totalExpense'] as num?)?.toDouble() ?? 0.0;
      }
      final cachedClasses = await CacheService.get(userId, CacheService.scheduleTodayClasses);
      if (cachedClasses != null && cachedClasses is Map<String, dynamic>) {
        _todayClasses = _processTodayClasses(cachedClasses);
      }
      final cachedActivity = await CacheService.get(userId, CacheService.activityTimeline);
      if (cachedActivity != null) _activityTimeline = cachedActivity;

      final cachedTodo = await CacheService.get(userId, CacheService.todoDailyCompletion);
      if (cachedTodo != null) _todoDaily = cachedTodo;

      final cachedTasks = await CacheService.get(userId, CacheService.taskUrgent);
      if (cachedTasks != null) _urgentTasks = cachedTasks;

      final cachedRecurring = await CacheService.get(userId, CacheService.financeRecurring);
      if (cachedRecurring != null && cachedRecurring is List) _recurringExpenses = cachedRecurring;

      // หากมีข้อมูลแคชอยู่แล้ว ปิดสถานะ _isLoading ทันที
      if (cachedFinance != null || cachedClasses != null || cachedTasks != null) {
        if (mounted) setState(() => _isLoading = false);
      } else {
        if (mounted) setState(() => _isLoading = true);
      }
    }

    try {
      final financeSummary = await FinanceApiService.getSummary(userId);
      if (financeSummary != null) {
        _netBalance = (financeSummary['netBalance'] as num?)?.toDouble() ?? 0.0;
        _totalIncome = (financeSummary['totalIncome'] as num?)?.toDouble() ?? 0.0;
        _totalExpense = (financeSummary['totalExpense'] as num?)?.toDouble() ?? 0.0;
        await CacheService.save(userId, CacheService.financeSummary, financeSummary);
      }

      final todayRes = await ScheduleApiService.getTodayClasses(userId);
      if (todayRes != null && todayRes is Map<String, dynamic>) {
        _todayClasses = _processTodayClasses(todayRes);
        await CacheService.save(userId, CacheService.scheduleTodayClasses, _todayClasses);
      }

      _activityTimeline = await ActivityApiService.getTimeline(userId);
      if (_activityTimeline != null) {
        await CacheService.save(userId, CacheService.activityTimeline, _activityTimeline);
      }

      _todoDaily = await TodoApiService.getDailyCompletion(userId);
      if (_todoDaily != null) {
        await CacheService.save(userId, CacheService.todoDailyCompletion, _todoDaily);
      }

      final urgentTasks = await TaskApiService.getUrgentTasks(userId);
      if (urgentTasks != null) {
        _urgentTasks = urgentTasks;
        await CacheService.save(userId, CacheService.taskUrgent, _urgentTasks);
      }

      final recurringList = await FinanceApiService.getRecurring(userId);
      if (recurringList != null && recurringList is List) {
        _recurringExpenses = recurringList;
        await CacheService.save(userId, CacheService.financeRecurring, _recurringExpenses);
      }

      if (_activityTimeline != null && _activityTimeline!['countdownSeconds'] != null) {
        final sec = (_activityTimeline!['countdownSeconds'] as num).toInt();
        _nextEventCountdown = Duration(seconds: sec > 0 ? sec : 0);
      }
    } catch (e, st) {
      Logger.catchBlock('OverviewPage', 'fetchDashboardData', e, st);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadBreakdown() async {
    if (mounted) setState(() => _isBreakdownLoading = true);
    try {
      final userId = await UserSession.getUserId();
      final res = await FinanceApiService.getBreakdown(
        userId,
        _breakdownPeriod,
        year: _breakdownPeriod == 'yearly' ? null : _breakdownYear,
        month: _breakdownPeriod == 'daily' ? _breakdownMonth : null,
      );
      if (res != null && res['data'] != null && mounted) {
        setState(() => _breakdownData = res['data']);
      }
    } catch (e, st) {
      Logger.catchBlock('OverviewPage', 'loadBreakdown', e, st);
    } finally {
      if (mounted) setState(() => _isBreakdownLoading = false);
    }
  }

  void _changeBreakdownPeriod(String period) {
    if (period == _breakdownPeriod) return;
    setState(() => _breakdownPeriod = period);
    _loadBreakdown();
  }

  void _shiftBreakdownRange(int delta) {
    setState(() {
      if (_breakdownPeriod == 'daily') {
        var newMonth = _breakdownMonth + delta;
        var newYear = _breakdownYear;
        if (newMonth < 1) {
          newMonth = 12;
          newYear--;
        } else if (newMonth > 12) {
          newMonth = 1;
          newYear++;
        }
        _breakdownMonth = newMonth;
        _breakdownYear = newYear;
      } else if (_breakdownPeriod == 'monthly') {
        _breakdownYear += delta;
      }
    });
    _loadBreakdown();
  }

  Map<String, dynamic> _processTodayClasses(Map<String, dynamic> data) {
    final allToday = data['allToday'];
    if (allToday == null || allToday is! List || allToday.isEmpty) {
      return data;
    }

    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    dynamic previous;
    List<dynamic> currentList = [];
    List<dynamic> nextList = [];
    String? earliestNextStart;

    for (var c in allToday) {
      final startStr = c['startTime']?.toString() ?? '00:00';
      final endStr = c['endTime']?.toString() ?? '00:00';
      final startParts = startStr.split(':');
      final endParts = endStr.split(':');
      final startMin = (int.tryParse(startParts[0]) ?? 0) * 60 + (int.tryParse(startParts[1]) ?? 0);
      final endMin = (int.tryParse(endParts[0]) ?? 0) * 60 + (int.tryParse(endParts[1]) ?? 0);

      if (endMin <= currentMinutes) {
        previous = c;
      } else if (startMin <= currentMinutes && endMin > currentMinutes) {
        // overlapping: multiple classes can be "current"
        currentList.add(c);
      } else if (startMin > currentMinutes) {
        // collect all classes starting at the earliest upcoming time
        if (earliestNextStart == null || startStr.compareTo(earliestNextStart) < 0) {
          earliestNextStart = startStr;
          nextList = [c];
        } else if (startStr == earliestNextStart) {
          nextList.add(c);
        }
      }
    }

    return {
      'allToday': allToday,
      'previous': previous,
      'currentList': currentList,
      'nextList': nextList,
      // keep single aliases for backward-compat with countdown calc
      'current': currentList.isNotEmpty ? currentList.first : null,
      'next': nextList.isNotEmpty ? nextList.first : null,
    };
  }

  void _calcClassCountdowns() {
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute + now.second / 60.0;

    // Use currentList — pick the one ending soonest for the countdown display
    final currentList = (_todayClasses?['currentList'] as List?);
    final currentFirst = currentList != null && currentList.isNotEmpty ? currentList.first : null;
    final next = _todayClasses?['next'];

    if (currentFirst != null) {
      final endStr = currentFirst['endTime']?.toString() ?? '00:00';
      final parts = endStr.split(':');
      final endMin = (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
      final remaining = endMin - currentMinutes;
      _currentClassRemaining = remaining > 0
          ? Duration(seconds: (remaining * 60).round())
          : Duration.zero;
    } else {
      _currentClassRemaining = Duration.zero;
    }

    if (next != null) {
      final startStr = next['startTime']?.toString() ?? '00:00';
      final parts = startStr.split(':');
      final startMin = (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
      final diffMin = startMin - currentMinutes;
      _nextClassCountdown = diffMin > 0
          ? Duration(seconds: (diffMin * 60).round())
          : Duration.zero;
    } else {
      _nextClassCountdown = Duration.zero;
    }
  }

  String _formatCountdown(Duration d) {
    if (d.inSeconds <= 0) return '';
    if (d.inHours >= 1) {
      final h = d.inHours;
      final m = d.inMinutes.remainder(60);
      return '$h ชม. $m นาที';
    }
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    if (m > 0) return '$m นาที ${s.toString().padLeft(2, '0')} วิ';
    return '$s วินาที';
  }

  String _formatTimer(Duration d) {
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${pad(d.inHours)}:${pad(d.inMinutes.remainder(60))}:${pad(d.inSeconds.remainder(60))}';
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'สวัสดีตอนเช้า';
    if (hour < 17) return 'สวัสดีตอนบ่าย';
    return 'สวัสดีตอนเย็น';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    return RefreshIndicator(
      onRefresh: _fetchDashboardData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        children: [
          const SizedBox(height: 8),
          if (_isLoading) ...[
            ValueListenableBuilder<bool>(
              valueListenable: ApiClient.isConnectingLong,
              builder: (context, isLong, child) {
                return ServerConnectingWidget(
                  message: isLong ? 'กำลังปลุกเซิร์ฟเวอร์ (Render Cold Start)...' : 'กำลังดึงข้อมูลล่าสุด...',
                  subMessage: isLong
                      ? 'เซิร์ฟเวอร์กำลังสตาร์ทขึ้นมาใหม่เนื่องจากไม่ได้ใช้งานเป็นเวลานาน โปรดรอประมาณ 20-40 วินาที...'
                      : 'โปรดรอสักครู่ ระบบกำลังจัดเตรียมข้อมูลของคุณ...',
                );
              },
            ),
            const SizedBox(height: 16),
            const SkeletonCard(height: 140, borderRadius: 24),
            const SizedBox(height: 16),
            const SkeletonCard(height: 100, borderRadius: 20),
          ]
          else ...[
            // Hero Balance Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: c.heroGradient,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: c.accent.withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${_greeting()}, $_userName',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.trending_up, color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text('สด', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text('ยอดเงินคงเหลือ',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text('฿${_netBalance.toStringAsFixed(2)}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _heroStat('รายรับ', '+฿${_totalIncome.toStringAsFixed(0)}', Icons.arrow_upward_rounded),
                      const SizedBox(width: 16),
                      _heroStat('รายจ่าย', '-฿${_totalExpense.toStringAsFixed(0)}', Icons.arrow_downward_rounded),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Quick Stats Row
            Row(
              children: [
                Expanded(child: _quickStat(c.accent, Icons.school_rounded, 'วิชาเรียน', _todayClasses?['current']?['courseName'] ?? '-',)),
                const SizedBox(width: 12),
                Expanded(child: _quickStat(c.violet, Icons.timer_rounded, 'ถัดไป', _formatTimer(_nextEventCountdown))),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _quickStat(c.good, Icons.check_circle_rounded, 'Todolist', '${((_todoDaily?['percentage'] as num?) ?? 0).toStringAsFixed(0)}%')),
                const SizedBox(width: 12),
                Expanded(child: _quickStat(c.coral, Icons.priority_high_rounded, 'งานด่วน', '${_urgentTasks.length} รายการ')),
              ],
            ),
            const SizedBox(height: 20),

            // Income vs Expense breakdown chart
            _buildBreakdownSection(c),
            const SizedBox(height: 16),

            // Recurring Expenses Section
            _buildRecurringExpensesSection(c),
            const SizedBox(height: 16),

            // Today's Classes
            SectionCard(
              title: 'วิชาเรียนวันนี้',
              caption: (_todayClasses?['termName'] != null && _todayClasses!['termName'].toString().isNotEmpty)
                  ? 'ภาคเรียน: ${_todayClasses!['termName']}'
                  : 'อัพเดทล่าสุด',
              child: Column(
                children: [
                  _classStatusTile(
                    'ก่อนหน้า',
                    _todayClasses?['previous']?['courseName'] ?? 'ไม่มีวิชาก่อนหน้า',
                    _todayClasses?['previous'] != null ? '${_todayClasses!['previous']['startTime']} - ${_todayClasses!['previous']['endTime']}' : '-',
                    c.ink3,
                  ),

                  // Current classes — could be multiple (overlapping)
                  ...() {
                    final currentList = (_todayClasses?['currentList'] as List?) ?? [];
                    if (currentList.isEmpty) {
                      return [
                        _classStatusTile(
                          'กำลังเรียน',
                          'ไม่มีวิชาที่กำลังเรียน',
                          '-',
                          c.accent,
                          isHighlight: false,
                        ),
                      ];
                    }
                    return currentList.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final cls = entry.value;
                      final label = currentList.length > 1
                          ? 'กำลังเรียน ${idx + 1}'
                          : 'กำลังเรียน';
                      return _classStatusTile(
                        label,
                        cls['courseName'] ?? '',
                        '${cls['startTime']} - ${cls['endTime']}',
                        c.accent,
                        isHighlight: true,
                        countdown: idx == 0 ? _currentClassRemaining : null,
                        countdownLabel: 'เหลือ',
                      );
                    }).toList();
                  }(),

                  // Next classes — could be multiple (same start time)
                  ...() {
                    final nextList = (_todayClasses?['nextList'] as List?) ?? [];
                    if (nextList.isEmpty) {
                      return [
                        _classStatusTile(
                          'ถัดไป',
                          'ไม่มีวิชาถัดไป',
                          '-',
                          c.blue,
                        ),
                      ];
                    }
                    return nextList.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final cls = entry.value;
                      final label = nextList.length > 1
                          ? 'ถัดไป ${idx + 1}'
                          : 'ถัดไป';
                      return _classStatusTile(
                        label,
                        cls['courseName'] ?? '',
                        '${cls['startTime']} - ${cls['endTime']}',
                        c.blue,
                        countdown: idx == 0 ? _nextClassCountdown : null,
                        countdownLabel: 'อีก',
                      );
                    }).toList();
                  }(),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Next Activity + Countdown
            SectionCard(
              title: 'กิจกรรมถัดไป',
              gradient: c.accentGradient,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        Text(_formatTimer(_nextEventCountdown),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
                        Text('นับถอยหลัง', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.8))),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _activityTimeline?['next']?['title'] ?? 'ไม่มีกิจกรรมถัดไป',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _activityTimeline?['next']?['location'] != null
                              ? _activityTimeline!['next']['location']
                              : 'ไม่มีข้อมูลสถานที่',
                          style: TextStyle(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.8)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Todolist Progress
            SectionCard(
              title: 'Todolist วันนี้',
              caption: 'เสร็จสิ้น ${((_todoDaily?['percentage'] as num?) ?? 0).toStringAsFixed(0)}%',
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: LinearProgressIndicator(
                      value: (((_todoDaily?['percentage'] as num?) ?? 0) / 100.0).clamp(0.0, 1.0),
                      backgroundColor: c.surface2,
                      valueColor: AlwaysStoppedAnimation(c.accent),
                      minHeight: 10,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_todoDaily?['todos'] != null && (_todoDaily!['todos'] as List).isNotEmpty)
                    for (var t in (_todoDaily!['todos'] as List).take(3))
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: t['isCompleted'] == true ? c.good.withValues(alpha: 0.08) : c.surface2,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              t['isCompleted'] == true ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                              color: t['isCompleted'] == true ? c.good : c.ink3,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                t['title'] ?? '',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  decoration: t['isCompleted'] == true ? TextDecoration.lineThrough : null,
                                  color: t['isCompleted'] == true ? c.ink3 : c.ink,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                  else
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text('ไม่มีรายการวันนี้', style: TextStyle(color: c.ink3, fontSize: 13)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Urgent Tasks
            if (_urgentTasks.isNotEmpty)
              SectionCard(
                title: 'งานเร่งด่วน',
                gradient: c.dangerGradient,
                child: Column(
                  children: [
                    for (var task in _urgentTasks.take(2))
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.warning_rounded, color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(task['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)),
                                  Text('กำหนดส่ง: ${task['deadline'] ?? '-'}', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _heroStat(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11)),
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickStat(Color color, IconData icon, String label, String value) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: c.ink3)),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.ink)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _classStatusTile(
    String tag,
    String title,
    String subtitle,
    Color color, {
    bool isHighlight = false,
    Duration? countdown,
    String? countdownLabel,
  }) {
    final c = context.c;
    final hasCountdown = countdown != null && countdown.inSeconds > 0;
    final countdownText = hasCountdown ? _formatCountdown(countdown) : null;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isHighlight ? color.withValues(alpha: 0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(tag, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: c.ink)),
                Text(subtitle, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.ink3)),
              ],
            ),
          ),
          if (countdownText != null) ...
            [
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      countdownLabel ?? '',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color.withValues(alpha: 0.7)),
                    ),
                    Text(
                      countdownText,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: color),
                    ),
                  ],
                ),
              ),
            ],
        ],
      ),
    );
  }

  Widget _buildBreakdownSection(AppColors c) {
    const periods = [
      ['daily', 'รายวัน'],
      ['monthly', 'รายเดือน'],
      ['yearly', 'รายปี'],
    ];

    final labels = _breakdownData.map((e) => '${e['label']}').toList();
    final incomes = _breakdownData.map((e) => (e['income'] as num).toDouble()).toList();
    final expenses = _breakdownData.map((e) => (e['expense'] as num).toDouble()).toList();
    final maxV = [...incomes, ...expenses, 1.0].reduce((a, b) => a > b ? a : b);

    String rangeLabel;
    if (_breakdownPeriod == 'daily') {
      rangeLabel = '${_breakdownMonth.toString().padLeft(2, '0')}/${_breakdownYear + 543}';
    } else if (_breakdownPeriod == 'monthly') {
      rangeLabel = '${_breakdownYear + 543}';
    } else {
      rangeLabel = 'ทุกปี';
    }

    return SectionCard(
      title: 'เปรียบเทียบรายรับ-รายจ่าย',
      caption: 'ภาพรวมตามช่วงเวลา',
      icon: Icons.insights_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: periods.map((p) {
              final selected = _breakdownPeriod == p[0];
              return Expanded(
                child: GestureDetector(
                  onTap: () => _changeBreakdownPeriod(p[0]),
                  child: Container(
                    margin: EdgeInsets.only(right: p != periods.last ? 8 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: selected ? c.accent : c.surface2,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(p[1],
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: selected ? Colors.white : c.ink3)),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          if (_breakdownPeriod != 'yearly')
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => _shiftBreakdownRange(-1),
                    child: Icon(Icons.chevron_left_rounded, color: c.ink3),
                  ),
                  Text(rangeLabel, style: TextStyle(fontWeight: FontWeight.w700, color: c.ink, fontSize: 13.5)),
                  GestureDetector(
                    onTap: () => _shiftBreakdownRange(1),
                    child: Icon(Icons.chevron_right_rounded, color: c.ink3),
                  ),
                ],
              ),
            ),

          if (_isBreakdownLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (labels.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('ยังไม่มีข้อมูล', style: TextStyle(color: c.ink3, fontSize: 13))),
            )
          else ...[
            Row(
              children: [
                TrendLegend(color: c.good, icon: Icons.arrow_upward_rounded, label: 'รายรับ (เส้นทึบ)'),
                const SizedBox(width: 16),
                TrendLegend(color: c.coral, icon: Icons.arrow_downward_rounded, label: 'รายจ่าย (เส้นประ)'),
              ],
            ),
            const SizedBox(height: 12),
            CompareTrendChart(
              labels: labels,
              a: incomes,
              b: expenses,
              colorA: c.good,
              colorB: c.coral,
              maxV: maxV,
              height: 150,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecurringExpensesSection(AppColors c) {
    if (_recurringExpenses.isEmpty) {
      return SectionCard(
        title: 'รายจ่ายประจำใกล้ที่สุด',
        caption: 'อัพเดทล่าสุด',
        icon: Icons.event_repeat_rounded,
        iconColor: c.amber,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('ยังไม่มีรายการจ่ายประจำ', style: TextStyle(color: c.ink3)),
        ),
      );
    }

    final now = DateTime.now();
    final todayOnly = DateTime(now.year, now.month, now.day);

    dynamic nearestItem;
    DateTime? nearestNextDue;
    int minDays = 999999;

    for (var r in _recurringExpenses) {
      final day = (r['dayOfMonthDue'] as num?)?.toInt() ?? 1;
      DateTime dueDateFor(int y, int m) {
        final daysInMonth = DateTime(y, m + 1, 0).day;
        return DateTime(y, m, day.clamp(1, daysInMonth));
      }

      var nextDue = dueDateFor(now.year, now.month);
      if (nextDue.isBefore(todayOnly)) {
        final nextMonth = now.month == 12 ? 1 : now.month + 1;
        final nextYear = now.month == 12 ? now.year + 1 : now.year;
        nextDue = dueDateFor(nextYear, nextMonth);
      }

      final daysUntil = nextDue.difference(todayOnly).inDays;
      if (daysUntil < minDays) {
        minDays = daysUntil;
        nearestItem = r;
        nearestNextDue = nextDue;
      }
    }

    if (nearestItem == null || nearestNextDue == null) {
      return SectionCard(
        title: 'รายจ่ายประจำใกล้ที่สุด',
        caption: 'อัพเดทล่าสุด',
        icon: Icons.event_repeat_rounded,
        iconColor: c.amber,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('ยังไม่มีรายการจ่ายประจำ', style: TextStyle(color: c.ink3)),
        ),
      );
    }

    final dueTarget = DateTime(nearestNextDue.year, nearestNextDue.month, nearestNextDue.day, 23, 59, 59);
    final remaining = dueTarget.difference(now);

    String countdownText;
    if (remaining.isNegative) {
      countdownText = 'เลยกำหนด';
    } else if (minDays == 0) {
      final h = remaining.inHours.toString().padLeft(2, '0');
      final m = remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
      countdownText = 'เหลือ $h:$m:$s';
    } else {
      final h = remaining.inHours.remainder(24).toString().padLeft(2, '0');
      final m = remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
      countdownText = '$minDaysวัน $h:$m:$s';
    }

    final day = (nearestItem['dayOfMonthDue'] as num?)?.toInt() ?? 1;
    final amt = (nearestItem['amount'] as num?)?.toDouble() ?? 0.0;
    final title = nearestItem['title'] ?? '';

    final dueLabel = minDays == 0 ? 'ครบกำหนดวันนี้' : 'อีก $minDays วัน';
    final Color dueFg = minDays == 0 ? c.coral : (minDays <= 3 ? c.amber : c.ink3);
    final Color dueBg = minDays == 0 ? c.coralSoft : (minDays <= 3 ? c.amberSoft : c.surface2);

    return SectionCard(
      title: 'รายจ่ายประจำใกล้ที่สุด',
      caption: 'รายการถัดไปที่ต้องชำระ',
      icon: Icons.event_repeat_rounded,
      iconColor: c.amber,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.amberSoft.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.amber.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: minDays == 0 ? [c.coral, c.amber] : [c.amber, c.accent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: (minDays == 0 ? c.coral : c.amber).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer_rounded, color: Colors.white, size: 18),
                  const SizedBox(height: 4),
                  Text(
                    countdownText,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                  Text(
                    'นับถอยหลัง',
                    style: TextStyle(
                      fontSize: 9.5,
                      color: Colors.white.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: c.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'จ่ายทุกวันที่ $day ของเดือน',
                    style: TextStyle(fontSize: 12, color: c.ink3, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 6),
                  Pill(dueLabel, fg: dueFg, bg: dueBg),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '฿${amt.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: c.ink,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
