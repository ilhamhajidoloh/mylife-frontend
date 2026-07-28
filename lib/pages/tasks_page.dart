import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../services/api_client.dart';
import '../services/api_services.dart';
import '../services/user_session.dart';
import '../services/cache_service.dart';
import '../services/logger.dart';
import '../services/notification_service.dart';
import '../services/data_event_service.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  bool _isLoading = true;
  List<dynamic> _tasks = [];
  List<dynamic> _urgentTasks = [];

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    final userId = await UserSession.getUserId();

    // 1. อ่านข้อมูลจาก Cache ก่อน
    final cachedTasks = await CacheService.get(userId, CacheService.tasks);
    if (cachedTasks != null) _tasks = cachedTasks;

    final cachedUrgent = await CacheService.get(userId, CacheService.taskUrgent);
    if (cachedUrgent != null) _urgentTasks = cachedUrgent;

    if (cachedTasks != null || cachedUrgent != null) {
      if (mounted) setState(() => _isLoading = false);
    } else {
      if (mounted) setState(() => _isLoading = true);
    }

    try {
      final list = await TaskApiService.getTasks(userId);
      if (list != null && list is List) {
        _tasks = list;
        await CacheService.save(userId, CacheService.tasks, list);
        for (final task in list) {
          await _scheduleTaskDeadlineNotification(task);
        }
      }

      final urgent = await TaskApiService.getUrgentTasks(userId);
      if (urgent != null && urgent is List) {
        _urgentTasks = urgent;
        await CacheService.save(userId, CacheService.taskUrgent, urgent);
      }
    } catch (e, st) {
      Logger.catchBlock('TasksPage', 'loadTasks', e, st);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// ตั้งเตือนก่อนถึงกำหนดส่ง 1 วัน (หรือ 2 ชม.ก่อน ถ้าเหลือเวลาน้อยกว่านั้น) — งานที่เสร็จแล้วจะยกเลิกแจ้งเตือนทิ้ง
  Future<void> _scheduleTaskDeadlineNotification(dynamic task) async {
    try {
      final id = task['id'];
      if (id == null) return;
      final notifId = (id.toString().hashCode).abs() % 2147483647;

      if (task['isCompleted'] == true || task['deadline'] == null) {
        await NotificationService.cancelNotification(notifId);
        return;
      }

      final deadline = DateTime.tryParse(task['deadline'].toString());
      if (deadline == null) return;

      var reminderTime = deadline.subtract(const Duration(hours: 24));
      if (reminderTime.isBefore(DateTime.now())) {
        reminderTime = deadline.subtract(const Duration(hours: 2));
      }

      await NotificationService.scheduleNotification(
        id: notifId,
        title: '📌 ใกล้ถึงกำหนดส่ง: ${task['title'] ?? ''}',
        body: 'วิชา: ${(task['subject'] as String?)?.isNotEmpty == true ? task['subject'] : '-'} — ${_formatDeadline(task['deadline'])}',
        scheduledDate: reminderTime,
      );
    } catch (e, st) {
      Logger.catchBlock('TasksPage', 'scheduleTaskDeadlineNotification', e, st);
    }
  }

  void _openTaskModal([dynamic item]) {
    final isEdit = item != null;
    final titleController = TextEditingController(text: item?['title'] ?? '');
    final subjectController = TextEditingController(text: item?['subject'] ?? '');
    bool isUrgent = item?['isUrgent'] == true;
    DateTime deadline = isEdit && item['deadline'] != null
        ? (DateTime.tryParse(item['deadline']) ?? DateTime.now().add(const Duration(days: 2)))
        : DateTime.now().add(const Duration(days: 2));

    showAppBottomSheet(
      context,
      title: isEdit ? 'แก้ไขงาน' : 'เพิ่มงานใหม่',
      child: StatefulBuilder(
        builder: (context, setModalState) {
          final cc = context.c;
          const thMonths = ['', 'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.', 'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'];
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppModalField(controller: titleController, label: 'ชื่องาน / การบ้าน', icon: Icons.assignment_rounded),
              const SizedBox(height: 12),
              AppModalField(controller: subjectController, label: 'วิชา / หมวดหมู่', icon: Icons.subject_rounded),
              const SizedBox(height: 16),
              AppModalSection(
                title: 'กำหนดส่ง',
                child: GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: deadline,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                      builder: (ctx, child) => Theme(
                        data: Theme.of(ctx).copyWith(colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: cc.accent)),
                        child: child!,
                      ),
                    );
                    if (picked == null || !context.mounted) return;
                    final pickedTime = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(deadline),
                      builder: (ctx, child) => Theme(
                        data: Theme.of(ctx).copyWith(colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: cc.accent)),
                        child: child!,
                      ),
                    );
                    setModalState(() => deadline = DateTime(
                          picked.year,
                          picked.month,
                          picked.day,
                          pickedTime?.hour ?? deadline.hour,
                          pickedTime?.minute ?? deadline.minute,
                        ));
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(color: cc.surface2, borderRadius: BorderRadius.circular(14)),
                    child: Row(
                      children: [
                        Icon(Icons.event_rounded, size: 18, color: cc.accent),
                        const SizedBox(width: 10),
                        Text(
                          '${deadline.day} ${thMonths[deadline.month]} ${deadline.year + 543}  ${deadline.hour.toString().padLeft(2, '0')}:${deadline.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(fontWeight: FontWeight.w700, color: cc.ink),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Urgent toggle
              GestureDetector(
                onTap: () => setModalState(() => isUrgent = !isUrgent),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isUrgent ? cc.coralSoft : cc.surface2,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isUrgent ? cc.coral.withValues(alpha: 0.4) : cc.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isUrgent ? cc.coral.withValues(alpha: 0.15) : cc.border.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isUrgent ? Icons.warning_rounded : Icons.flag_outlined,
                          color: isUrgent ? cc.coral : cc.ink3,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('งานเร่งด่วน',
                                style: TextStyle(fontWeight: FontWeight.w700, color: isUrgent ? cc.coral : cc.ink, fontSize: 14)),
                            Text('กำหนดส่งเร็ว',
                                style: TextStyle(fontSize: 12, color: cc.ink3)),
                          ],
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 48,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isUrgent ? cc.coral : cc.border,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: AnimatedAlign(
                          duration: const Duration(milliseconds: 200),
                          alignment: isUrgent ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            width: 24,
                            height: 24,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
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
                      onTap: () async {
                        await TaskApiService.deleteTask(item['id']);
                        await NotificationService.cancelNotification((item['id'].toString().hashCode).abs() % 2147483647);
                        if (context.mounted) Navigator.pop(context);
                        _loadTasks();
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
                      isDestructive: isUrgent,
                      onPressed: () async {
                        if (titleController.text.trim().isEmpty) return;
                        final userId = await UserSession.getUserId();
                        dynamic saved;
                        if (isEdit) {
                          saved = await TaskApiService.updateTask(item['id'], titleController.text, subjectController.text, isUrgent, item['isCompleted'] == true, deadline);
                        } else {
                          saved = await TaskApiService.addTask(userId, titleController.text, subjectController.text, isUrgent, deadline);
                        }
                        await _scheduleTaskDeadlineNotification(saved);

                        if (context.mounted) Navigator.pop(context);
                        _loadTasks();
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

  static const _thMonths = ['', 'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.', 'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'];

  String _formatDeadline(dynamic raw) {
    if (raw == null) return '-';
    final dt = DateTime.tryParse(raw.toString());
    if (dt == null) return '-';
    return 'กำหนดส่ง ${dt.day} ${_thMonths[dt.month]} ${dt.year + 543}';
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
          onPressed: () => _openTaskModal(),
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text('เพิ่มงาน', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadTasks,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
          children: [
            const PageHeader(title: 'งาน & การบ้าน', subtitle: 'จัดการงานและกำหนดส่ง'),
            const SizedBox(height: 16),

            if (_isLoading) ...[
              ValueListenableBuilder<bool>(
                valueListenable: ApiClient.isConnectingLong,
                builder: (context, isLong, child) {
                  return ServerConnectingWidget(
                    message: isLong ? 'กำลังปลุกเซิร์ฟเวอร์...' : 'กำลังดึงรายการงาน...',
                    subMessage: isLong
                        ? 'เซิร์ฟเวอร์กำลังเริ่มต้นทำงาน โปรดรอสักครู่...'
                        : 'กำลังดึงงานและการบ้านของคุณ...',
                  );
                },
              ),
              const SizedBox(height: 16),
              const SkeletonCard(height: 120, borderRadius: 20),
            ]
            else ...[
              // Urgent Tasks
              if (_urgentTasks.isNotEmpty) ...[
                SectionCard(
                  title: 'งานเร่งด่วน',
                  gradient: c.dangerGradient,
                  child: Column(
                    children: [
                      for (var task in _urgentTasks)
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
                                child: const Icon(Icons.priority_high_rounded, color: Colors.white, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(task['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)),
                                    Text('วิชา: ${task['subject'] ?? '-'} • ${_formatDeadline(task['deadline'])}', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete_outline_rounded, color: Colors.white.withValues(alpha: 0.7)),
                                onPressed: () async {
                                  await TaskApiService.deleteTask(task['id']);
                                  await NotificationService.cancelNotification((task['id'].toString().hashCode).abs() % 2147483647);
                                  _loadTasks();
                                  DataEventService.notifyDataChanged();
                                },
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // All Tasks
              SectionCard(
                title: 'งานทั้งหมด',
                caption: '${_tasks.length} งาน',
                child: _tasks.isNotEmpty
                    ? Column(
                        children: [
                          for (var task in _tasks)
                            Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: task['isCompleted'] == true
                                    ? c.good.withValues(alpha: 0.06)
                                    : task['isUrgent'] == true
                                        ? c.coralSoft.withValues(alpha: 0.5)
                                        : c.surface2,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  GestureDetector(
                                    onTap: () async {
                                      final deadline = task['deadline'] != null
                                          ? (DateTime.tryParse(task['deadline']) ?? DateTime.now().add(const Duration(days: 2)))
                                          : DateTime.now().add(const Duration(days: 2));
                                      final newCompleted = !(task['isCompleted'] == true);
                                      final saved = await TaskApiService.updateTask(
                                        task['id'], task['title'], task['subject'] ?? '', task['isUrgent'] == true, newCompleted, deadline,
                                      );
                                      await _scheduleTaskDeadlineNotification(saved ?? {...task, 'isCompleted': newCompleted});
                                      _loadTasks();
                                      DataEventService.notifyDataChanged();
                                    },
                                    child: Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        gradient: task['isCompleted'] == true
                                            ? LinearGradient(colors: [c.good, c.good.withValues(alpha: 0.8)])
                                            : null,
                                        color: task['isCompleted'] != true ? Colors.transparent : null,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: task['isCompleted'] == true ? c.good : c.border,
                                          width: 2,
                                        ),
                                      ),
                                      child: task['isCompleted'] == true
                                          ? const Icon(Icons.check, size: 16, color: Colors.white)
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          task['title'] ?? '',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                            decoration: task['isCompleted'] == true ? TextDecoration.lineThrough : null,
                                            color: task['isCompleted'] == true ? c.ink3 : c.ink,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text('วิชา: ${task['subject'] ?? '-'} • ${_formatDeadline(task['deadline'])}',
                                            style: TextStyle(fontSize: 12, color: c.ink3)),
                                      ],
                                    ),
                                  ),
                                  if (task['isUrgent'] == true)
                                    Pill('ด่วน', fg: c.coral, bg: c.coralSoft),
                                  IconButton(
                                    icon: Icon(Icons.delete_outline_rounded, size: 20, color: c.coral),
                                    onPressed: () async {
                                      await TaskApiService.deleteTask(task['id']);
                                      await NotificationService.cancelNotification((task['id'].toString().hashCode).abs() % 2147483647);
                                      _loadTasks();
                                      DataEventService.notifyDataChanged();
                                    },
                                  ),
                                ],
                              ),
                            ),
                        ],
                      )
                    : Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text('ยังไม่มีงาน กด + เพื่อเพิ่ม', style: TextStyle(color: c.ink3)),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
