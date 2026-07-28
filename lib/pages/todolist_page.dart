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
        year: _viewAnchor.year,
        month: _selectedView == 'ปี' ? null : _viewAnchor.month,
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
      case 'วัน':
        return '${_viewAnchor.day} ${thMonths[_viewAnchor.month]} ${_viewAnchor.year + 543}';
      case 'เดือน':
        return '${thMonths[_viewAnchor.month]} ${_viewAnchor.year + 543}';
      default:
        return '${_viewAnchor.year + 543}';
    }
  }

  String _recurrenceLabel(dynamic value) {
    switch ((value as num?)?.toInt() ?? 0) {
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
    int recurrence = isEdit && item['recurrence'] != null
        ? (item['recurrence'] as num).toInt()
        : 0;
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
                    if (picked != null)
                      setModalState(() => targetDate = picked);
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
              // Progress Ring Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: c.accent.withValues(alpha: 0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: c.accent.withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    ProgressRing(
                      progress: _completionPercentage,
                      centerTop:
                          '${(_completionPercentage * 100).toStringAsFixed(0)}%',
                      centerBottom: 'สำเร็จ',
                      color: c.accent,
                      size: 84,
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ความสำเร็จวันนี้',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: c.ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$_completedCount / $_totalCount รายการ',
                            style: TextStyle(fontSize: 14, color: c.ink3),
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: LinearProgressIndicator(
                              value: _completionPercentage.clamp(0.0, 1.0),
                              backgroundColor: c.surface2,
                              valueColor: AlwaysStoppedAnimation(c.accent),
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

              // View mode
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: c.surface2,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: ['วัน', 'เดือน', 'ปี'].map((v) {
                    final isSel = _selectedView == v;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => _changeView(v),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isSel ? c.surface : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: isSel
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.06,
                                      ),
                                      blurRadius: 8,
                                    ),
                                  ]
                                : [],
                          ),
                          child: Text(
                            v,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSel
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              color: isSel ? c.ink : c.ink3,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 10),

              // Range navigator
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => _shiftView(-1),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: c.surface2,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.chevron_left_rounded,
                        color: c.ink3,
                        size: 20,
                      ),
                    ),
                  ),
                  Text(
                    _rangeLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: c.ink,
                      fontSize: 13.5,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _shiftView(1),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: c.surface2,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: c.ink3,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

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
                                  final targetDate = item['targetDate'] != null
                                      ? (DateTime.tryParse(
                                              item['targetDate'],
                                            ) ??
                                            _viewAnchor)
                                      : _viewAnchor;
                                  await TodoApiService.updateTodo(
                                    item['id'],
                                    item['title'],
                                    item['tag'] ?? 'ทั่วไป',
                                    targetDate,
                                    (item['recurrence'] as num?)?.toInt() ?? 0,
                                    !(item['isCompleted'] == true),
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
}
