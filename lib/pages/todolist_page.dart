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

class TodolistPage extends StatefulWidget {
  const TodolistPage({super.key});

  @override
  State<TodolistPage> createState() => _TodolistPageState();
}

class _TodolistPageState extends State<TodolistPage> {
  bool _isLoading = true;
  String _selectedView = 'วัน';
  String _selectedTag = 'ทั้งหมด';
  DateTime _viewAnchor = DateTime.now();

  static const List<Map<String, dynamic>> _recurrenceOptions = [
    {'label': 'เป็นวันที่', 'value': 0},
    {'label': 'ทุกวัน', 'value': 1},
    {'label': 'ทุกสัปดาห์', 'value': 2},
    {'label': 'ทุกเดือน', 'value': 3},
    {'label': 'ทุกปี', 'value': 4},
  ];

  List<dynamic> _todos = [];

  double get _completionPercentage =>
      _totalCount > 0 ? _completedCount / _totalCount : 0.0;
  int get _completedCount =>
      _todos.where((t) => t['isCompleted'] == true).length;
  int get _totalCount => _todos.length;

  String get _cacheKey =>
      '${CacheService.todos}_${_selectedTag}_$_selectedView'
      '_${_viewAnchor.year}_${_selectedView == 'วัน' ? _viewAnchor.month : ''}_${_selectedView == 'วัน' ? _viewAnchor.day : ''}'
      '_${_selectedView == 'เดือน' ? _viewAnchor.month : ''}';

  @override
  void initState() {
    super.initState();
    _loadTodos();
  }

  Future<void> _loadTodos() async {
    final userId = await UserSession.getUserId();

    // 1. อ่านข้อมูลจาก Cache ก่อน
    final cachedTodos = await CacheService.get(userId, _cacheKey);
    if (cachedTodos != null) _todos = cachedTodos;

    if (cachedTodos != null) {
      if (mounted) setState(() => _isLoading = false);
    } else {
      if (mounted) setState(() => _isLoading = true);
    }

    try {
      final list = await TodoApiService.getTodos(
        userId,
        tag: _selectedTag,
        year: _selectedView == 'ทั้งหมด' ? null : _viewAnchor.year,
        month: (_selectedView == 'ปี' || _selectedView == 'ทั้งหมด') ? null : _viewAnchor.month,
        day: _selectedView == 'วัน' ? _viewAnchor.day : null,
      );
      if (list != null && list is List) {
        _todos = list;
        await CacheService.save(userId, _cacheKey, list);
      }
    } catch (e, st) {
      Logger.catchBlock('TodolistPage', 'loadTodos', e, st);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _changeView(String view) {
    if (view == _selectedView) return;
    setState(() => _selectedView = view);
    _loadTodos();
  }

  void _shiftView(int delta) {
    if (_selectedView == 'ทั้งหมด') return;
    setState(() {
      switch (_selectedView) {
        case 'วัน':
          _viewAnchor = _viewAnchor.add(Duration(days: delta));
          break;
        case 'เดือน':
          var newMonth = _viewAnchor.month + delta;
          var newYear = _viewAnchor.year;
          if (newMonth < 1) {
            newMonth = 12;
            newYear--;
          } else if (newMonth > 12) {
            newMonth = 1;
            newYear++;
          }
          _viewAnchor = DateTime(newYear, newMonth, 1);
          break;
        case 'ปี':
          _viewAnchor = DateTime(
            _viewAnchor.year + delta,
            _viewAnchor.month,
            _viewAnchor.day,
          );
          break;
      }
    });
    _loadTodos();
  }

  String get _rangeLabel {
    const thMonths = [
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
    switch (_selectedView) {
      case 'ทั้งหมด':
        return 'รายการทั้งหมด';
      case 'วัน':
        return '${_viewAnchor.day} ${thMonths[_viewAnchor.month]} ${_viewAnchor.year + 543}';
      case 'เดือน':
        return '${thMonths[_viewAnchor.month]} ${_viewAnchor.year + 543}';
      default:
        return '${_viewAnchor.year + 543}';
    }
  }

  int _parseRecurrence(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toInt();
    if (value is String) {
      final p = int.tryParse(value);
      if (p != null) return p;
      switch (value.toLowerCase().trim()) {
        case 'daily':
          return 1;
        case 'weekly':
          return 2;
        case 'monthly':
          return 3;
        case 'yearly':
          return 4;
        default:
          return 0;
      }
    }
    return 0;
  }

  String _recurrenceLabel(dynamic value) {
    switch (_parseRecurrence(value)) {
      case 1:
        return 'ทุกวัน';
      case 2:
        return 'ทุกสัปดาห์';
      case 3:
        return 'ทุกเดือน';
      case 4:
        return 'ทุกปี';
      default:
        return 'เป็นวันที่';
    }
  }

  void _openTodoModal([dynamic item]) {
    final isEdit = item != null;
    final titleController = TextEditingController(text: item?['title'] ?? '');
    String tag = item?['tag'] ?? 'เรียน';
    int recurrence = isEdit ? _parseRecurrence(item?['recurrence']) : 0;
    DateTime targetDate = isEdit && item['targetDate'] != null
        ? (DateTime.tryParse(item['targetDate']) ?? _viewAnchor)
        : _viewAnchor;

    showAppBottomSheet(
      context,
      title: isEdit ? 'แก้ไข Todolist' : 'เพิ่ม Todolist ใหม่',
      child: StatefulBuilder(
        builder: (context, setModalState) {
          final cc = context.c;
          const thMonths = [
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
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppModalField(
                controller: titleController,
                label: 'รายการที่ต้องทำ',
                icon: Icons.check_circle_outline_rounded,
              ),
              const SizedBox(height: 16),
              AppModalSection(
                title: 'รูปแบบวันที่ต้องทำ',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _recurrenceOptions.map((option) {
                    final isSel = recurrence == option['value'];
                    return GestureDetector(
                      onTap: () => setModalState(
                        () => recurrence = option['value'] as int,
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isSel
                              ? cc.accent.withValues(alpha: 0.12)
                              : cc.surface2,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSel
                                ? cc.accent.withValues(alpha: 0.35)
                                : cc.border,
                          ),
                        ),
                        child: Text(
                          option['label'] as String,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSel
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSel ? cc.accent : cc.ink3,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
              AppModalSection(
                title: recurrence == 0 ? 'วันที่ต้องทำ' : 'วันที่เริ่มต้น',
                child: GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: targetDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                      builder: (ctx, child) => Theme(
                        data: Theme.of(ctx).copyWith(
                          colorScheme: Theme.of(
                            ctx,
                          ).colorScheme.copyWith(primary: cc.accent),
                        ),
                        child: child!,
                      ),
                    );
                    if (picked != null) {
                      setModalState(() => targetDate = picked);
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: cc.surface2,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 18,
                          color: cc.accent,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${targetDate.day} ${thMonths[targetDate.month]} ${targetDate.year + 543}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: cc.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              AppModalSection(
                title: 'เลือกแท็ก',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['เรียน', 'งาน', 'ส่วนตัว', 'สุขภาพ'].map((t) {
                    final isSel = tag == t;
                    final color = _tagColor(t);
                    return GestureDetector(
                      onTap: () => setModalState(() => tag = t),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isSel
                              ? color.withValues(alpha: 0.12)
                              : cc.surface2,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSel
                                ? color.withValues(alpha: 0.4)
                                : cc.border,
                          ),
                        ),
                        child: Text(
                          t,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSel
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSel ? color : cc.ink3,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  if (isEdit) ...[
                    GestureDetector(
                      onTap: () async {
                        await TodoApiService.deleteTodo(item['id']);
                        if (context.mounted) Navigator.pop(context);
                        _loadTodos();
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
                        if (isEdit) {
                          await TodoApiService.updateTodo(
                            item['id'],
                            titleController.text,
                            tag,
                            targetDate,
                            recurrence,
                            item['isCompleted'] == true,
                          );
                        } else {
                          await TodoApiService.addTodo(
                            userId,
                            titleController.text,
                            tag,
                            targetDate,
                            recurrence,
                          );
                        }
                        if (context.mounted) Navigator.pop(context);
                        _loadTodos();
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

  Color _tagColor(String tag) {
    switch (tag) {
      case 'เรียน':
        return context.c.accent;
      case 'งาน':
        return context.c.amber;
      case 'ส่วนตัว':
        return context.c.violet;
      case 'สุขภาพ':
        return context.c.good;
      default:
        return context.c.ink3;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
          onPressed: () => _openTodoModal(),
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text(
            'เพิ่ม Todolist',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadTodos,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
          children: [
            const PageHeader(
              title: 'Todolist',
              subtitle: 'จัดการรายการที่ต้องทำ',
            ),
            const SizedBox(height: 16),

            if (_isLoading) ...[
              ValueListenableBuilder<bool>(
                valueListenable: ApiClient.isConnectingLong,
                builder: (context, isLong, child) {
                  return ServerConnectingWidget(
                    message: isLong
                        ? 'กำลังปลุกเซิร์ฟเวอร์...'
                        : 'กำลังดึง Todolist...',
                    subMessage: isLong
                        ? 'เซิร์ฟเวอร์กำลังเริ่มต้นทำงาน โปรดรอสักครู่...'
                        : 'กำลังดึงรายการสิ่งที่ต้องทำของคุณ...',
                  );
                },
              ),
              const SizedBox(height: 16),
              const SkeletonCard(height: 120, borderRadius: 20),
            ] else ...[
              // 1. Hero Focus Bento Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: c.heroGradient,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: c.accent.withValues(alpha: 0.32),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: ProgressRing(
                        progress: _completionPercentage,
                        centerTop:
                            '${(_completionPercentage * 100).toStringAsFixed(0)}%',
                        centerBottom: 'สำเร็จ',
                        color: Colors.white,
                        size: 80,
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFF4ADE80),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'TODAY FOCUS',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'เป้าหมายวันนี้',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$_completedCount จาก $_totalCount งานสำเร็จแล้ว',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.85),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: _completionPercentage.clamp(0.0, 1.0),
                              backgroundColor: Colors.white.withValues(alpha: 0.2),
                              valueColor: const AlwaysStoppedAnimation(Color(0xFF4ADE80)),
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 2. View Mode Switcher & Range Navigator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? c.border.withValues(alpha: 0.8) : c.border.withValues(alpha: 0.6),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? Colors.black.withValues(alpha: 0.2) : c.ink.withValues(alpha: 0.03),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: ['ทั้งหมด', 'วัน', 'เดือน', 'ปี'].map((v) {
                        final isSel = _selectedView == v;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => _changeView(v),
                            behavior: HitTestBehavior.opaque,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: isSel ? c.accentSoft : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: isSel
                                    ? Border.all(color: c.accent.withValues(alpha: 0.25))
                                    : null,
                              ),
                              child: Text(
                                v,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                                  color: isSel ? c.accent : c.ink3,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    if (_selectedView != 'ทั้งหมด') ...[
                      const Divider(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: () => _shiftView(-1),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: c.surface2,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.chevron_left_rounded, color: c.ink2, size: 18),
                            ),
                          ),
                          Text(
                            _rangeLabel,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: c.ink,
                              fontSize: 13,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _shiftView(1),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: c.surface2,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.chevron_right_rounded, color: c.ink2, size: 18),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Tag chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['ทั้งหมด', 'เรียน', 'งาน', 'ส่วนตัว', 'สุขภาพ']
                      .map((t) {
                        final isSel = _selectedTag == t;
                        final color = t == 'ทั้งหมด' ? c.accent : _tagColor(t);
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _selectedTag = t);
                              _loadTodos();
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isSel
                                    ? color.withValues(alpha: 0.12)
                                    : c.surface2,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSel
                                      ? color.withValues(alpha: 0.3)
                                      : c.border.withValues(alpha: 0.5),
                                ),
                              ),
                              child: Text(
                                t,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isSel ? color : c.ink3,
                                ),
                              ),
                            ),
                          ),
                        );
                      })
                      .toList(),
                ),
              ),
              const SizedBox(height: 16),

              // Todo List
              SectionCard(
                title: 'รายการ',
                caption: _rangeLabel,
                child: Column(
                  children: [
                    if (_todos.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'ยังไม่มีรายการ กด + เพื่อสร้าง',
                          style: TextStyle(color: c.ink3),
                        ),
                      )
                    else
                      for (var item in _todos)
                        Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: item['isCompleted'] == true
                                ? c.good.withValues(alpha: 0.06)
                                : c.surface2,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () async {
                                  final completionDate = _selectedView == 'วัน'
                                      ? _viewAnchor
                                      : (item['targetDate'] != null
                                            ? (DateTime.tryParse(item['targetDate']) ?? _viewAnchor)
                                            : _viewAnchor);
                                  await TodoApiService.updateCompletion(
                                    item['id'],
                                    !(item['isCompleted'] == true),
                                    completionDate,
                                  );
                                  _loadTodos();
                                  DataEventService.notifyDataChanged();
                                },
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    gradient: item['isCompleted'] == true
                                        ? LinearGradient(
                                            colors: [
                                              c.good,
                                              c.good.withValues(alpha: 0.8),
                                            ],
                                          )
                                        : null,
                                    color: item['isCompleted'] != true
                                        ? Colors.transparent
                                        : null,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: item['isCompleted'] == true
                                          ? c.good
                                          : c.border,
                                      width: 2,
                                    ),
                                  ),
                                  child: item['isCompleted'] == true
                                      ? const Icon(
                                          Icons.check,
                                          size: 16,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['title'] ?? '',
                                      style: TextStyle(
                                        decoration: item['isCompleted'] == true
                                            ? TextDecoration.lineThrough
                                            : null,
                                        color: item['isCompleted'] == true
                                            ? c.ink3
                                            : c.ink,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      'แท็ก: ${item['tag'] ?? 'ทั่วไป'}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: c.accent,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      'รูปแบบ: ${_recurrenceLabel(item['recurrence'])}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: c.ink3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'แก้ไขรายการ',
                                icon: Icon(
                                  Icons.edit_outlined,
                                  size: 20,
                                  color: c.accent,
                                ),
                                onPressed: () => _openTodoModal(item),
                              ),
                              IconButton(
                                tooltip: 'ลบรายการ',
                                icon: Icon(
                                  Icons.delete_outline_rounded,
                                  size: 20,
                                  color: c.coral,
                                ),
                                onPressed: () async {
                                  await TodoApiService.deleteTodo(item['id']);
                                  _loadTodos();
                                  DataEventService.notifyDataChanged();
                                },
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
      ),
    );
  }

  Widget _buildTagChip(String label, String icon, bool isSelected, Color color) {
    final c = context.c;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedTag = label);
          _loadTodos();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [color, color.withOpacity(0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isSelected ? null : c.surface2,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? color : c.border.withOpacity(0.5),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(icon, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? Colors.white : c.ink3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
