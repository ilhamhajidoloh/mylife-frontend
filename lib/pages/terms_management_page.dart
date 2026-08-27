import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/api_services.dart';
import '../services/user_session.dart';
import '../services/logger.dart';

class TermsManagementPage extends StatefulWidget {
  const TermsManagementPage({super.key});

  @override
  State<TermsManagementPage> createState() => _TermsManagementPageState();
}

class _TermsManagementPageState extends State<TermsManagementPage> {
  bool _isLoading = true;
  List<dynamic> _terms = [];

  @override
  void initState() {
    super.initState();
    _loadTerms();
  }

  Future<void> _loadTerms() async {
    setState(() => _isLoading = true);
    try {
      final userId = await UserSession.getUserId();
      if (userId.isEmpty) return;

      final data = await ScheduleApiService.getTerms(userId);
      setState(() {
        _terms = data ?? [];
        _isLoading = false;
      });
    } catch (e) {
      Logger.error('TermsManagementPage', 'Load terms error: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _openTermForm({Map<String, dynamic>? term}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TermFormModal(term: term),
    );

    if (result == true) {
      _loadTerms();
    }
  }

  Future<void> _deleteTerm(String termId, String termName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text(
          'คุณต้องการลบภาคเรียน "$termName" หรือไม่?\n\nตารางเรียนทั้งหมดในภาคนี้จะถูกลบด้วย',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ScheduleApiService.deleteTerm(termId);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('ลบภาคเรียนสำเร็จ')));
      }
      _loadTerms();
    } catch (e) {
      Logger.error('TermsManagementPage', 'Delete term error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('ลบภาคเรียนไม่สำเร็จ')));
      }
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: c.ink),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('จัดการภาคเรียน', style: TextStyle(color: c.ink)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: _terms.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 64,
                                color: c.ink3,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'ยังไม่มีภาคเรียน',
                                style: TextStyle(fontSize: 16, color: c.ink3),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _terms.length,
                          itemBuilder: (context, index) {
                            final term = _terms[index];
                            final startDate = _formatDate(term['startDate']);
                            final endDate = _formatDate(term['endDate']);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: c.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: c.border),
                              ),
                              child: ListTile(
                                leading: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: c.accent.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.school,
                                    color: c.accent,
                                    size: 24,
                                  ),
                                ),
                                title: Text(
                                  term['termName'] ?? term['name'] ?? '',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: c.ink,
                                  ),
                                ),
                                subtitle: Text(
                                  '$startDate - $endDate',
                                  style: TextStyle(fontSize: 12, color: c.ink3),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        Icons.edit_outlined,
                                        size: 20,
                                        color: c.ink3,
                                      ),
                                      onPressed: () =>
                                          _openTermForm(term: term),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.delete_outline,
                                        size: 20,
                                        color: c.coral,
                                      ),
                                      onPressed: () => _deleteTerm(
                                        term['id'],
                                        term['termName'] ?? term['name'] ?? '',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_terms',
        onPressed: () => _openTermForm(),
        backgroundColor: c.accent,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'สร้างภาคเรียน',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}

class _TermFormModal extends StatefulWidget {
  final Map<String, dynamic>? term;

  const _TermFormModal({this.term});

  @override
  State<_TermFormModal> createState() => _TermFormModalState();
}

class _TermFormModalState extends State<_TermFormModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.term?['termName'] ?? widget.term?['name'] ?? '',
    );

    if (widget.term != null) {
      try {
        if (widget.term!['startDate'] != null) {
          _startDate = DateTime.parse(widget.term!['startDate']);
        }
        if (widget.term!['endDate'] != null) {
          _endDate = DateTime.parse(widget.term!['endDate']);
        }
      } catch (e) {
        Logger.error('_TermFormModal', 'Parse date error: $e');
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart
          ? (_startDate ?? DateTime.now())
          : (_endDate ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเลือกวันที่เริ่มต้นและสิ้นสุด')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final userId = await UserSession.getUserId();
      if (userId.isEmpty) throw Exception('ไม่พบ userId');

      if (widget.term != null) {
        // Update
        await ScheduleApiService.updateTerm(
          widget.term!['id'],
          userId,
          _nameController.text.trim(),
          _startDate!,
          _endDate!,
        );
      } else {
        // Create
        await ScheduleApiService.addTerm(
          userId,
          _nameController.text.trim(),
          _startDate!,
          _endDate!,
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.term != null
                  ? 'แก้ไขภาคเรียนสำเร็จ'
                  : 'สร้างภาคเรียนสำเร็จ',
            ),
          ),
        );
      }
    } catch (e) {
      Logger.error('_TermFormModal', 'Submit term error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('บันทึกไม่สำเร็จ')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final mediaQuery = MediaQuery.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: c.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.term != null ? 'แก้ไขภาคเรียน' : 'สร้างภาคเรียนใหม่',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: c.ink,
                  ),
                ),
                const SizedBox(height: 24),

                // Name
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'ชื่อภาคเรียน',
                    hintText: 'เช่น ภาคเรียนที่ 1/2567',
                    labelStyle: TextStyle(color: c.ink3),
                    filled: true,
                    fillColor: c.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'กรุณาระบุชื่อภาคเรียน';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Start Date
                GestureDetector(
                  onTap: () => _pickDate(true),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, color: c.accent, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'วันที่เริ่มต้น',
                                style: TextStyle(fontSize: 12, color: c.ink3),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _startDate != null
                                    ? DateFormat(
                                        'dd MMMM yyyy',
                                        'th',
                                      ).format(_startDate!)
                                    : 'เลือกวันที่เริ่มต้น',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: c.ink,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // End Date
                GestureDetector(
                  onTap: () => _pickDate(false),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.event, color: c.coral, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'วันที่สิ้นสุด',
                                style: TextStyle(fontSize: 12, color: c.ink3),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _endDate != null
                                    ? DateFormat(
                                        'dd MMMM yyyy',
                                        'th',
                                      ).format(_endDate!)
                                    : 'เลือกวันที่สิ้นสุด',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: c.ink,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: c.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text('ยกเลิก', style: TextStyle(color: c.ink2)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: c.accent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                widget.term != null ? 'บันทึก' : 'สร้าง',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
