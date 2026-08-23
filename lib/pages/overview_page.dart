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

class _OverviewPageState extends State<OverviewPage>
    with WidgetsBindingObserver {
  bool _isLoading = true;
  bool _hideBalance = false;
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

  int _blinkTrigger = 0;

  void _updateNextEventCountdown() {
    if (_activityTimeline != null &&
        _activityTimeline!['next'] != null &&
        _activityTimeline!['next']['startTime'] != null) {
      final startTimeStr = _activityTimeline!['next']['startTime'].toString();
      final targetDate = DateTime.tryParse(startTimeStr)?.toLocal();
      if (targetDate != null) {
        final diff = targetDate.difference(DateTime.now());
        _nextEventCountdown = diff.isNegative ? Duration.zero : diff;
        return;
      }
    }
    if (_activityTimeline != null &&
        _activityTimeline!['countdownSeconds'] != null) {
      final sec =
          num.tryParse(
            _activityTimeline!['countdownSeconds'].toString(),
          )?.toInt() ??
          0;
      _nextEventCountdown = Duration(seconds: sec > 0 ? sec : 0);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
        if (_activityTimeline != null &&
            _activityTimeline!['next'] != null &&
            _activityTimeline!['next']['startTime'] != null) {
          _updateNextEventCountdown();
        } else if (_nextEventCountdown.inSeconds > 0) {
          _nextEventCountdown -= const Duration(seconds: 1);
        }
        _calcClassCountdowns();
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (mounted) {
        setState(() {
          _blinkTrigger++;
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer.cancel();
    _autoRefreshTimer?.cancel();
    _dataSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchDashboardData({bool silent = false}) async {
    final userId = await UserSession.getUserId();

    // 1. โหลดข้อมูลจาก Cache ทันทีเพื่อให้แสดงผลได้ทันทีโดยไม่ต้องรอ API (Stale-While-Revalidate)
    if (!silent) {
      final cachedFinance = await CacheService.get(
        userId,
        CacheService.financeSummary,
      );
      if (cachedFinance != null) {
        _netBalance = (cachedFinance['netBalance'] as num?)?.toDouble() ?? 0.0;
        _totalIncome =
            (cachedFinance['totalIncome'] as num?)?.toDouble() ?? 0.0;
        _totalExpense =
            (cachedFinance['totalExpense'] as num?)?.toDouble() ?? 0.0;
      }
      final cachedClasses = await CacheService.get(
        userId,
        CacheService.scheduleTodayClasses,
      );
      if (cachedClasses != null && cachedClasses is Map<String, dynamic>) {
        _todayClasses = _processTodayClasses(cachedClasses);
      }
      final cachedActivity = await CacheService.get(
        userId,
        CacheService.activityTimeline,
      );
      if (cachedActivity != null) {
        _activityTimeline = cachedActivity;
        _updateNextEventCountdown();
      }

      final cachedTodo = await CacheService.get(
        userId,
        CacheService.todoDailyCompletion,
      );
      if (cachedTodo != null) _todoDaily = cachedTodo;

      final cachedTasks = await CacheService.get(
        userId,
        CacheService.taskUrgent,
      );
      if (cachedTasks != null) _urgentTasks = cachedTasks;

      final cachedRecurring = await CacheService.get(
        userId,
        CacheService.financeRecurring,
      );
      if (cachedRecurring != null && cachedRecurring is List) {
        _recurringExpenses = cachedRecurring;
      }

      // หากมีข้อมูลแคชอยู่แล้ว ปิดสถานะ _isLoading ทันที
      if (cachedFinance != null ||
          cachedClasses != null ||
          cachedTasks != null) {
        if (mounted) setState(() => _isLoading = false);
      } else {
        if (mounted) setState(() => _isLoading = true);
      }
    }

    try {
      final financeSummary = await FinanceApiService.getSummary(userId);
      if (financeSummary != null) {
        _netBalance = (financeSummary['netBalance'] as num?)?.toDouble() ?? 0.0;
        _totalIncome =
            (financeSummary['totalIncome'] as num?)?.toDouble() ?? 0.0;
        _totalExpense =
            (financeSummary['totalExpense'] as num?)?.toDouble() ?? 0.0;
        await CacheService.save(
          userId,
          CacheService.financeSummary,
          financeSummary,
        );
      }

      final todayRes = await ScheduleApiService.getTodayClasses(userId);
      if (todayRes != null && todayRes is Map<String, dynamic>) {
        _todayClasses = _processTodayClasses(todayRes);
        await CacheService.save(
          userId,
          CacheService.scheduleTodayClasses,
          _todayClasses,
        );
      }

      _activityTimeline = await ActivityApiService.getTimeline(userId);
      if (_activityTimeline != null) {
        await CacheService.save(
          userId,
          CacheService.activityTimeline,
          _activityTimeline,
        );
      }

      _todoDaily = await TodoApiService.getDailyCompletion(userId);
      if (_todoDaily != null) {
        await CacheService.save(
          userId,
          CacheService.todoDailyCompletion,
          _todoDaily,
        );
      }

      final urgentTasks = await TaskApiService.getUrgentTasks(userId);
      if (urgentTasks != null) {
        _urgentTasks = urgentTasks;
        await CacheService.save(userId, CacheService.taskUrgent, _urgentTasks);
      }

      final recurringList = await FinanceApiService.getRecurring(userId);
      if (recurringList != null && recurringList is List) {
        _recurringExpenses = recurringList;
        await CacheService.save(
          userId,
          CacheService.financeRecurring,
          _recurringExpenses,
        );
      }

      _updateNextEventCountdown();
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
      final startMin =
          (int.tryParse(startParts[0]) ?? 0) * 60 +
          (int.tryParse(startParts[1]) ?? 0);
      final endMin =
          (int.tryParse(endParts[0]) ?? 0) * 60 +
          (int.tryParse(endParts[1]) ?? 0);

      if (endMin <= currentMinutes) {
        previous = c;
      } else if (startMin <= currentMinutes && endMin > currentMinutes) {
        // overlapping: multiple classes can be "current"
        currentList.add(c);
      } else if (startMin > currentMinutes) {
        // collect all classes starting at the earliest upcoming time
        if (earliestNextStart == null ||
            startStr.compareTo(earliestNextStart) < 0) {
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
    final currentFirst = currentList != null && currentList.isNotEmpty
        ? currentList.first
        : null;
    final next = _todayClasses?['next'];

    if (currentFirst != null) {
      final endStr = currentFirst['endTime']?.toString() ?? '00:00';
      final parts = endStr.split(':');
      final endMin =
          (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
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
      final startMin =
          (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
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
                  message: isLong
                      ? 'กำลังปลุกเซิร์ฟเวอร์ (Render Cold Start)...'
                      : 'กำลังดึงข้อมูลล่าสุด...',
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
          ] else ...[
            // 1. ZONE 1: Live Focus Spotlight
            _buildLiveFocusSpotlight(c),
            const SizedBox(height: 16),

            // 2. ZONE 2: Today's Bento Grid
            _buildDigitalWalletBento(c),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(child: _buildTodoBento(c)),
                const SizedBox(width: 12),
                Expanded(child: _buildUrgentTasksBento(c)),
              ],
            ),
            const SizedBox(height: 16),

            // 3. ZONE 3: Today's Timeline (Classes & Schedule)
            _buildTodayClassesSection(c),
            const SizedBox(height: 16),

            // 4. ZONE 4: Next Scheduled Activity
            _buildNextActivityCard(c),
            const SizedBox(height: 16),

            // 5. ZONE 5: Financial Insights & Breakdown Chart
            _buildBreakdownSection(c),
            const SizedBox(height: 16),

            // 6. ZONE 6: Recurring Expenses Section
            _buildRecurringExpensesSection(c),
          ],
        ],
      ),
    );
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
    return (remSec / totalSec).clamp(0.0, 1.0);
  }

  /// คำนวณ progress สำหรับกิจกรรมถัดไป (หลอดเพิ่มขึ้นในรอบ 30 วัน ถ้ายังไม่ถึง 30 วัน ไม่ต้องขึ้น)
  double? _calculateNextActivityProgress(dynamic act, Duration remaining) {
    if (act == null) return null;
    final remSec = remaining.inSeconds;
    const thirtyDaysInSeconds = 30 * 24 * 3600; // 2,592,000 วินาที

    if (remSec > thirtyDaysInSeconds) return null;
    if (remSec <= 0) return 1.0;

    return (1.0 - (remSec / thirtyDaysInSeconds)).clamp(0.0, 1.0);
  }

  Widget _buildLiveFocusSpotlight(AppColors c) {
    final currentList = (_todayClasses?['currentList'] as List?) ?? [];
    final hasOngoingClass = currentList.isNotEmpty;
    final hasOngoingActivity =
        _activityTimeline != null &&
        _activityTimeline!['current'] != null &&
        _activityTimeline!['current']['title'] != null;
    final nextList = (_todayClasses?['nextList'] as List?) ?? [];
    final hasNextClass = nextList.isNotEmpty;
    final hasNextActivity =
        _activityTimeline != null &&
        _activityTimeline!['next'] != null &&
        _activityTimeline!['next']['title'] != null;

    if (hasOngoingClass) {
      final cls = currentList.first;
      final courseName = cls['courseName']?.toString() ?? 'วิชาเรียน';
      final room = cls['room']?.toString() ?? '';
      final timeRange = '${cls['startTime']} - ${cls['endTime']}';
      final remainingStr = _currentClassRemaining.inSeconds > 0
          ? _formatCountdown(_currentClassRemaining)
          : null;

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF059669), Color(0xFF10B981)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.school_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'กำลังเรียนอยู่ (LIVE)',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white.withValues(alpha: 0.95),
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (remainingStr != null) ...[
                        const Spacer(),
                        Text(
                          'เหลือ $remainingStr',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    courseName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [timeRange, if (room.isNotEmpty) 'ห้อง $room'].join(' • '),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (hasOngoingActivity) {
      final act = _activityTimeline!['current'];
      final actTitle = act['title']?.toString() ?? 'กิจกรรม';
      final location = act['location']?.toString() ?? '';
      final ongoingProgress = _calculateOngoingProgress(act);

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_circle_fill_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF4ADE80),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'กำลังดำเนินการ (ONGOING)',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                              color: Colors.white.withValues(alpha: 0.95),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        actTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                      if (location.isNotEmpty)
                        Text(
                          'สถานที่: $location',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
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
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                  Text(
                    '${(ongoingProgress * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: ongoingProgress,
                  backgroundColor: Colors.white.withValues(alpha: 0.22),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF60A5FA)),
                  minHeight: 6,
                ),
              ),
            ],
          ],
        ),
      );
    }

    if (hasNextClass) {
      final cls = nextList.first;
      final courseName = cls['courseName']?.toString() ?? 'วิชาถัดไป';
      final room = cls['room']?.toString() ?? '';
      final timeRange = '${cls['startTime']} - ${cls['endTime']}';
      final countdownStr = _nextClassCountdown.inSeconds > 0
          ? _formatCountdown(_nextClassCountdown)
          : null;

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: c.heroGradient,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: c.accent.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.timer_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'วิชาเรียนถัดไป',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                      if (countdownStr != null) ...[
                        const Spacer(),
                        Text(
                          'อีก $countdownStr',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    courseName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    [timeRange, if (room.isNotEmpty) 'ห้อง $room'].join(' • '),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (hasNextActivity) {
      final act = _activityTimeline!['next'];
      final nextProgress = _calculateNextActivityProgress(
        act,
        _nextEventCountdown,
      );

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: c.accentGradient,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: c.accent.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _formatTimer(_nextEventCountdown),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        'นับถอยหลัง',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Colors.white.withValues(alpha: 0.8),
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
                        act['title']?.toString() ?? 'กิจกรรมถัดไป',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        act['location'] != null &&
                                act['location'].toString().isNotEmpty
                            ? act['location'].toString()
                            : 'กำหนดการที่กำลังจะมาถึง',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (nextProgress != null) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'นับถอยหลังรอบ 30 วัน',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                  Text(
                    '${(nextProgress * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: nextProgress,
                  backgroundColor: Colors.white.withValues(alpha: 0.22),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF4ADE80)),
                  minHeight: 6,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildDigitalWalletBento(AppColors c) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: c.walletGradient,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.16),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: c.accent.withValues(alpha: 0.28),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.account_balance_wallet_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'กระเป๋าหลัก',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _hideBalance = !_hideBalance),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _hideBalance
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _hideBalance ? 'แสดง' : 'ซ่อน',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'ยอดเงินคงเหลือ',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _hideBalance
                ? '฿ • • • • • •'
                : '฿${_netBalance.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _heroStat(
                'รายรับ',
                _hideBalance ? '฿ •••' : '+฿${_totalIncome.toStringAsFixed(0)}',
                Icons.arrow_downward_rounded,
                c.good,
              ),
              const SizedBox(width: 12),
              _heroStat(
                'รายจ่าย',
                _hideBalance
                    ? '฿ •••'
                    : '-฿${_totalExpense.toStringAsFixed(0)}',
                Icons.arrow_upward_rounded,
                c.coral,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTodoBento(AppColors c) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pct = ((_todoDaily?['percentage'] as num?) ?? 0).toDouble();
    final todos = (_todoDaily?['todos'] as List?) ?? [];
    final completedCount = todos.where((t) => t['isCompleted'] == true).length;
    final totalCount = todos.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark
              ? c.border.withValues(alpha: 0.8)
              : c.border.withValues(alpha: 0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.25)
                : c.ink.withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: c.good.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.check_circle_rounded,
                  color: c.good,
                  size: 20,
                ),
              ),
              Text(
                '${pct.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: c.good,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Todolist วันนี้',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: c.ink,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            totalCount > 0
                ? 'เสร็จ $completedCount จาก $totalCount งาน'
                : 'ไม่มีงานค้าง',
            style: TextStyle(
              fontSize: 12,
              color: c.ink3,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: (pct / 100.0).clamp(0.0, 1.0),
              backgroundColor: c.surface2,
              valueColor: AlwaysStoppedAnimation(c.good),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUrgentTasksBento(AppColors c) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final urgentCount = _urgentTasks.length;
    final firstTask = urgentCount > 0 ? _urgentTasks.first : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark
              ? c.border.withValues(alpha: 0.8)
              : c.border.withValues(alpha: 0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.25)
                : c.ink.withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: c.coral.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.priority_high_rounded,
                  color: c.coral,
                  size: 20,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: c.coralSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$urgentCount รายการ',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: c.coral,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'งานเร่งด่วน',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: c.ink,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            firstTask != null
                ? (firstTask['title'] ?? 'งานที่ต้องส่ง')
                : 'ไม่มีงานด่วน',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: c.ink3,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: urgentCount > 0 ? 1.0 : 0.0,
              backgroundColor: c.surface2,
              valueColor: AlwaysStoppedAnimation(
                urgentCount > 0 ? c.coral : c.good,
              ),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayClassesSection(AppColors c) {
    return SectionCard(
      title: 'วิชาเรียนวันนี้',
      caption:
          (_todayClasses?['termName'] != null &&
              _todayClasses!['termName'].toString().isNotEmpty)
          ? (_todayClasses!['termName'].toString().startsWith('ภาคเรียน')
                ? '${_todayClasses!['termName']}'
                : 'ภาคเรียน: ${_todayClasses!['termName']}')
          : 'ตารางเรียนประจำวัน',
      icon: Icons.calendar_today_rounded,
      child: Column(
        children: [
          _classStatusTile(
            'ก่อนหน้า',
            _todayClasses?['previous']?['courseName'] ?? 'ไม่มีวิชาก่อนหน้า',
            _todayClasses?['previous'] != null
                ? '${_todayClasses!['previous']['startTime']} - ${_todayClasses!['previous']['endTime']}'
                : '-',
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
                key: ValueKey(
                  'overview-current-${cls['id'] ?? cls['courseId'] ?? cls['courseName'] ?? idx}-${cls['startTime']}',
                ),
                isHighlight: true,
                shouldBlink: true,
                countdown: idx == 0 ? _currentClassRemaining : null,
                countdownLabel: 'เหลือ',
              );
            }).toList();
          }(),

          // Next classes — could be multiple (same start time)
          ...() {
            final nextList = (_todayClasses?['nextList'] as List?) ?? [];
            if (nextList.isEmpty) {
              return [_classStatusTile('ถัดไป', 'ไม่มีวิชาถัดไป', '-', c.blue)];
            }
            final shouldBlinkNext =
                ((_todayClasses?['currentList'] as List?) ?? []).isEmpty;
            return nextList.asMap().entries.map((entry) {
              final idx = entry.key;
              final cls = entry.value;
              final label = nextList.length > 1 ? 'ถัดไป ${idx + 1}' : 'ถัดไป';
              return _classStatusTile(
                label,
                cls['courseName'] ?? '',
                '${cls['startTime']} - ${cls['endTime']}',
                c.blue,
                key: ValueKey(
                  'overview-next-${cls['id'] ?? cls['courseId'] ?? cls['courseName'] ?? idx}-${cls['startTime']}',
                ),
                shouldBlink: shouldBlinkNext,
                countdown: idx == 0 ? _nextClassCountdown : null,
                countdownLabel: 'อีก',
              );
            }).toList();
          }(),
        ],
      ),
    );
  }

  Widget _buildNextActivityCard(AppColors c) {
    if (_activityTimeline?['next'] == null) return const SizedBox.shrink();
    final next = _activityTimeline!['next'];
    final nextProgress = _calculateNextActivityProgress(
      next,
      _nextEventCountdown,
    );

    return SectionCard(
      title: 'กิจกรรมถัดไป',
      caption: 'นัดหมายสำคัญ',
      icon: Icons.celebration_rounded,
      gradient: c.accentGradient,
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      _formatTimer(_nextEventCountdown),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      'นับถอยหลัง',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      next['title']?.toString() ?? 'กิจกรรม',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      next['location'] != null &&
                              next['location'].toString().isNotEmpty
                          ? next['location'].toString()
                          : 'ไม่มีข้อมูลสถานที่',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (nextProgress != null) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'นับถอยหลังรอบ 30 วัน',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                Text(
                  '${(nextProgress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: nextProgress,
                backgroundColor: Colors.white.withValues(alpha: 0.22),
                valueColor: const AlwaysStoppedAnimation(Color(0xFF4ADE80)),
                minHeight: 6,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _heroStat(
    String label,
    String value,
    IconData icon, [
    Color? iconColor,
  ]) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: (iconColor ?? Colors.white).withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _classStatusTile(
    String tag,
    String title,
    String subtitle,
    Color color, {
    Key? key,
    bool isHighlight = false,
    bool shouldBlink = false,
    Duration? countdown,
    String? countdownLabel,
  }) {
    final c = context.c;
    final hasCountdown = countdown != null && countdown.inSeconds > 0;
    final countdownText = hasCountdown ? _formatCountdown(countdown) : null;

    return _BlinkingClassStatusTile(
      key: key,
      tag: tag,
      title: title,
      subtitle: subtitle,
      color: color,
      normalTitleColor: c.ink,
      normalSubtitleColor: c.ink3,
      isHighlight: isHighlight,
      shouldBlink: shouldBlink,
      countdownText: countdownText,
      countdownLabel: countdownLabel,
      blinkTrigger: _blinkTrigger,
    );
  }

  Widget _buildBreakdownSection(AppColors c) {
    const periods = [
      ['daily', 'รายวัน'],
      ['monthly', 'รายเดือน'],
      ['yearly', 'รายปี'],
    ];

    final labels = _breakdownData.map((e) => '${e['label']}').toList();
    final incomes = _breakdownData
        .map((e) => (e['income'] as num).toDouble())
        .toList();
    final expenses = _breakdownData
        .map((e) => (e['expense'] as num).toDouble())
        .toList();
    final maxV = [...incomes, ...expenses, 1.0].reduce((a, b) => a > b ? a : b);

    String rangeLabel;
    if (_breakdownPeriod == 'daily') {
      rangeLabel =
          '${_breakdownMonth.toString().padLeft(2, '0')}/${_breakdownYear + 543}';
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
                    child: Text(
                      p[1],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: selected ? Colors.white : c.ink3,
                      ),
                    ),
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
                  Text(
                    rangeLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: c.ink,
                      fontSize: 13.5,
                    ),
                  ),
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
              child: Center(
                child: Text(
                  'ยังไม่มีข้อมูล',
                  style: TextStyle(color: c.ink3, fontSize: 13),
                ),
              ),
            )
          else ...[
            Row(
              children: [
                TrendLegend(
                  color: c.good,
                  icon: Icons.arrow_upward_rounded,
                  label: 'รายรับ (เส้นทึบ)',
                ),
                const SizedBox(width: 16),
                TrendLegend(
                  color: c.coral,
                  icon: Icons.arrow_downward_rounded,
                  label: 'รายจ่าย (เส้นประ)',
                ),
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

  DateTime _calculateNextDue(dynamic r) {
    final day = (r['dayOfMonthDue'] as num?)?.toInt() ?? 1;
    final now = DateTime.now();
    final todayOnly = DateTime(now.year, now.month, now.day);
    final firstOfThisMonth = DateTime(todayOnly.year, todayOnly.month, 1);

    DateTime startDate = now;
    if (r['startDate'] != null) {
      try {
        startDate = DateTime.parse(r['startDate']);
      } catch (_) {}
    }

    final searchFrom = startDate.isAfter(firstOfThisMonth)
        ? startDate
        : firstOfThisMonth;

    DateTime dueDateFor(int y, int m) {
      final daysInMonth = DateTime(y, m + 1, 0).day;
      return DateTime(y, m, day.clamp(1, daysInMonth));
    }

    var nextDue = dueDateFor(searchFrom.year, searchFrom.month);
    if (nextDue.isBefore(searchFrom)) {
      final nextMonth = searchFrom.month == 12 ? 1 : searchFrom.month + 1;
      final nextYear = searchFrom.month == 12
          ? searchFrom.year + 1
          : searchFrom.year;
      nextDue = dueDateFor(nextYear, nextMonth);
    }
    return nextDue;
  }

  void _confirmPayRecurring(dynamic item, BuildContext parentContext) {
    final c = parentContext.c;
    final title = item['title'] ?? '';
    final amt = (item['amount'] as num?)?.toDouble() ?? 0.0;
    final nextDue = _calculateNextDue(item);
    final fmtDue = '${nextDue.day}/${nextDue.month}/${nextDue.year + 543}';

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
                decoration: BoxDecoration(
                  color: c.accentSoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.check_circle_rounded,
                  color: c.accent,
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'ยืนยันการชำระเงิน',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: c.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'ยืนยันว่าได้ชำระ "$title" จำนวน ฿${amt.toStringAsFixed(0)} (รอบวันที่ $fmtDue) แล้วใช่หรือไม่?',
                style: TextStyle(fontSize: 13.5, color: c.ink3, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: c.surface2,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 14, color: c.ink3),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'ระบบจะจดบันทึกเป็นรายจ่าย และขยับกำหนดชำระเป็นรอบถัดไป',
                        style: TextStyle(fontSize: 11, color: c.ink3),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: AppModalButton(
                      label: 'ยังไม่ได้จ่าย',
                      onPressed: () => Navigator.pop(ctx),
                      isPrimary: false,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppModalButton(
                      label: 'ยืนยัน (จ่ายแล้ว)',
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _executePayRecurring(item, parentContext);
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

  Future<void> _executePayRecurring(
    dynamic item,
    BuildContext parentContext,
  ) async {
    final userId = await UserSession.getUserId();
    final id = item['id'].toString();
    final title = item['title'] ?? '';
    final amt = (item['amount'] as num?)?.toDouble() ?? 0.0;
    final category = item['category'] ?? 'ค่าใช้จ่ายประจำ';
    final isIndefinite = item['isIndefinite'] ?? true;
    final dayOfMonthDue = (item['dayOfMonthDue'] as num?)?.toInt() ?? 1;
    final endDate = item['endDate'] != null
        ? DateTime.parse(item['endDate'])
        : null;

    final currentNextDue = _calculateNextDue(item);
    final newStartDate = currentNextDue.add(const Duration(days: 1));

    try {
      // 1. จดใน รายจ่าย
      await FinanceApiService.addTransaction(
        userId,
        amt,
        false,
        category,
        'ชำระรายจ่ายประจำ: $title',
      );

      // 2. ขยับไป รายจ่ายประจำ อันถัดไป
      await FinanceApiService.updateRecurring(
        id,
        userId,
        title,
        amt,
        category,
        newStartDate,
        endDate,
        isIndefinite,
        dayOfMonthDue,
      );

      _fetchDashboardData(silent: true);
      _loadBreakdown();
      DataEventService.notifyDataChanged();

      if (parentContext.mounted) {
        final nextDueAfter = _calculateNextDue({
          ...item,
          'startDate': newStartDate.toIso8601String(),
        });
        final fmtNext =
            '${nextDueAfter.day}/${nextDueAfter.month}/${nextDueAfter.year + 543}';
        ScaffoldMessenger.of(parentContext).showSnackBar(
          SnackBar(
            content: Text(
              'บันทึกรายจ่าย ฿${amt.toStringAsFixed(0)} เรียบร้อยแล้ว (รอบถัดไป: $fmtNext)',
            ),
            backgroundColor: parentContext.c.accent,
          ),
        );
      }
    } catch (e) {
      if (parentContext.mounted) {
        ScaffoldMessenger.of(parentContext).showSnackBar(
          SnackBar(
            content: Text(
              'เกิดข้อผิดพลาด: ${e.toString().replaceAll("Exception: ", "")}',
            ),
          ),
        );
      }
    }
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
          child: Text(
            'ยังไม่มีรายการจ่ายประจำ',
            style: TextStyle(color: c.ink3),
          ),
        ),
      );
    }

    final now = DateTime.now();
    final todayOnly = DateTime(now.year, now.month, now.day);

    dynamic nearestItem;
    DateTime? nearestNextDue;
    int minDays = 999999;

    for (var r in _recurringExpenses) {
      final nextDue = _calculateNextDue(r);
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
          child: Text(
            'ยังไม่มีรายการจ่ายประจำ',
            style: TextStyle(color: c.ink3),
          ),
        ),
      );
    }

    // คำนวณเวลาครบกำหนดที่ 23:59:59 ของวันนั้น เพื่อ countdown ที่แม่นยำ
    final dueTarget = DateTime(
      nearestNextDue.year,
      nearestNextDue.month,
      nearestNextDue.day,
      23,
      59,
      59,
    );
    final remaining = dueTarget.difference(now);

    String countdownText;
    if (remaining.isNegative) {
      countdownText = 'เลยกำหนด';
    } else if (minDays == 0) {
      // ครบกำหนดวันนี้ - แสดงแค่ ชม:นาที:วินาที
      final h = remaining.inHours.toString().padLeft(2, '0');
      final m = remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
      countdownText = 'เหลือ $h:$m:$s';
    } else {
      // เหลือหลายวัน - แสดง X วัน HH:MM:SS
      final h = remaining.inHours.remainder(24).toString().padLeft(2, '0');
      final m = remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
      countdownText = '$minDays วัน $h:$m:$s';
    }

    final day = (nearestItem['dayOfMonthDue'] as num?)?.toInt() ?? 1;
    final amt = (nearestItem['amount'] as num?)?.toDouble() ?? 0.0;
    final title = nearestItem['title'] ?? '';

    final dueLabel = minDays == 0
        ? 'ครบกำหนดวันนี้'
        : (minDays < 0 ? 'เลยกำหนด ${minDays.abs()} วัน' : 'อีก $minDays วัน');
    final Color dueFg = minDays <= 0
        ? c.coral
        : (minDays <= 3 ? c.amber : c.ink3);
    final Color dueBg = minDays <= 0
        ? c.coralSoft
        : (minDays <= 3 ? c.amberSoft : c.surface2);

    // คำนวณ progress bar (จากวันที่เริ่มรอบจนถึงวันครบกำหนด)
    final startDate = nearestItem['startDate'] != null
        ? DateTime.parse(nearestItem['startDate'])
        : DateTime(now.year, now.month, 1);
    final totalDuration = nearestNextDue
        .difference(startDate)
        .inSeconds
        .toDouble();
    final elapsed = now.difference(startDate).inSeconds.toDouble();
    final progress = totalDuration > 0
        ? (elapsed / totalDuration).clamp(0.0, 1.0)
        : 0.0;

    return SectionCard(
      title: 'รายจ่ายประจำใกล้ที่สุด',
      caption: 'รายการถัดไปที่ต้องชำระ',
      icon: Icons.event_repeat_rounded,
      iconColor: c.amber,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.amberSoft.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.amber.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: minDays <= 0
                              ? [c.coral, c.amber]
                              : [c.amber, c.accent],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: (minDays <= 0 ? c.coral : c.amber)
                                .withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.timer_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
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
                            style: TextStyle(
                              fontSize: 12,
                              color: c.ink3,
                              fontWeight: FontWeight.w500,
                            ),
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
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () =>
                              _confirmPayRecurring(nearestItem, context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: c.accentSoft,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: c.accent.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  size: 14,
                                  color: c.accent,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'จ่ายแล้ว',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: c.accent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Progress bar แสดงความคืบหน้าจากเริ่มรอบจนถึงครบกำหนด
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'ความคืบหน้า',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: c.ink3,
                          ),
                        ),
                        Text(
                          '${(progress * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: minDays <= 0 ? c.coral : c.amber,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: c.surface2,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: FractionallySizedBox(
                          widthFactor: progress,
                          alignment: Alignment.centerLeft,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: minDays <= 0
                                    ? [c.coral, c.amber]
                                    : progress > 0.7
                                    ? [c.amber, c.coral]
                                    : [c.accent, c.amber],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BlinkingClassStatusTile extends StatefulWidget {
  final String tag;
  final String title;
  final String subtitle;
  final Color color;
  final Color normalTitleColor;
  final Color normalSubtitleColor;
  final bool isHighlight;
  final bool shouldBlink;
  final String? countdownText;
  final String? countdownLabel;
  final int? blinkTrigger;

  const _BlinkingClassStatusTile({
    super.key,
    required this.tag,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.normalTitleColor,
    required this.normalSubtitleColor,
    required this.isHighlight,
    required this.shouldBlink,
    this.countdownText,
    this.countdownLabel,
    this.blinkTrigger,
  });

  @override
  State<_BlinkingClassStatusTile> createState() =>
      _BlinkingClassStatusTileState();
}

class _BlinkingClassStatusTileState extends State<_BlinkingClassStatusTile>
    with SingleTickerProviderStateMixin {
  static const _blinkColor = Color(0xFF0F172A);
  late final AnimationController _controller;
  late final Animation<double> _blink;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _blink = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 1), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1, end: 0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0, end: 1), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1, end: 0), weight: 1),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _syncBlink();
  }

  @override
  void didUpdateWidget(covariant _BlinkingClassStatusTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shouldBlink != widget.shouldBlink ||
        oldWidget.blinkTrigger != widget.blinkTrigger) {
      _syncBlink();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _syncBlink() {
    if (widget.shouldBlink) {
      _controller.forward(from: 0);
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _blink,
      builder: (context, child) {
        final blinkValue = widget.shouldBlink ? _blink.value : 0.0;
        final normalBg = widget.isHighlight
            ? widget.color.withValues(alpha: 0.08)
            : Colors.transparent;
        final bgColor = Color.lerp(normalBg, _blinkColor, blinkValue)!;
        final titleColor = Color.lerp(
          widget.normalTitleColor,
          Colors.white,
          blinkValue,
        )!;
        final subtitleColor = Color.lerp(
          widget.normalSubtitleColor,
          Colors.white.withValues(alpha: 0.78),
          blinkValue,
        )!;
        final accentTextColor = Color.lerp(
          widget.color,
          Colors.white,
          blinkValue,
        )!;
        final tagBgColor = Color.lerp(
          widget.color.withValues(alpha: 0.12),
          Colors.white.withValues(alpha: 0.18),
          blinkValue,
        )!;
        final countdownBgColor = Color.lerp(
          widget.color.withValues(alpha: 0.13),
          Colors.white.withValues(alpha: 0.16),
          blinkValue,
        )!;
        final countdownBorderColor = Color.lerp(
          widget.color.withValues(alpha: 0.25),
          Colors.white.withValues(alpha: 0.28),
          blinkValue,
        )!;

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: tagBgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.tag,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: accentTextColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: titleColor,
                      ),
                    ),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: subtitleColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.countdownText != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: countdownBgColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: countdownBorderColor, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.countdownLabel ?? '',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: Color.lerp(
                            widget.color.withValues(alpha: 0.7),
                            Colors.white.withValues(alpha: 0.75),
                            blinkValue,
                          ),
                        ),
                      ),
                      Text(
                        widget.countdownText!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: accentTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _NotificationCenterSheet extends StatefulWidget {
  final String userId;

  const _NotificationCenterSheet({required this.userId});

  @override
  State<_NotificationCenterSheet> createState() =>
      _NotificationCenterSheetState();
}

class _NotificationCenterSheetState extends State<_NotificationCenterSheet> {
  bool _isLoading = true;
  List<dynamic> _notifications = [];

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    try {
      final res = await NotificationApiService.getNotifications(widget.userId);
      if (res != null && res is List) {
        _notifications = res;
      }
    } catch (_) {
      _notifications = [];
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  IconData _getTypeIcon(String? type) {
    switch (type) {
      case 'balance':
        return Icons.account_balance_wallet_outlined;
      case 'class':
        return Icons.school_outlined;
      case 'activity':
        return Icons.event_outlined;
      case 'task':
        return Icons.assignment_late_outlined;
      default:
        return Icons.notifications_active_outlined;
    }
  }

  Color _getSeverityColor(String? severity, AppColors colors) {
    switch (severity) {
      case 'high':
        return colors.coral;
      case 'medium':
        return colors.amber;
      default:
        return colors.accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>() ?? AppColors.light;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.notifications_active, color: colors.accent),
                const SizedBox(width: 10),
                Text(
                  'การแจ้งเตือนจากระบบ (Backend)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colors.ink,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    setState(() => _isLoading = true);
                    _fetchNotifications();
                  },
                ),
              ],
            ),
          ),

          const Divider(),

          // Body
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _notifications.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 48,
                          color: colors.ink3,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'ไม่มีรายการแจ้งเตือนในขณะนี้',
                          style: TextStyle(color: colors.ink2, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notifications.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = _notifications[index];
                      final type = item['type']?.toString();
                      final title = item['title']?.toString() ?? 'การแจ้งเตือน';
                      final message = item['message']?.toString() ?? '';
                      final severity = item['severity']?.toString();
                      final color = _getSeverityColor(severity, colors);

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: colors.surface2,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: colors.border),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: color.withValues(alpha: 0.15),
                              child: Icon(
                                _getTypeIcon(type),
                                color: color,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: colors.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    message,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: colors.ink2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
