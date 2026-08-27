import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../services/api_services.dart';
import '../services/user_session.dart';
import '../services/logger.dart';

class BooksManagementPage extends StatefulWidget {
  const BooksManagementPage({super.key});

  @override
  State<BooksManagementPage> createState() => _BooksManagementPageState();
}

class _BooksManagementPageState extends State<BooksManagementPage> {
  bool _isLoading = true;
  List<dynamic> _books = [];

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  Future<void> _loadBooks() async {
    setState(() => _isLoading = true);
    try {
      final userId = await UserSession.getUserId();
      if (userId == null) return;

      final data = await BookApiService.getBooks(userId);
      setState(() {
        _books = data ?? [];
        _isLoading = false;
      });
    } catch (e) {
      Logger.error('BooksManagementPage', 'Load books error: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _openBookForm({Map<String, dynamic>? book}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _BookFormModal(book: book),
    );

    if (result == true) {
      _loadBooks();
    }
  }

  Future<void> _deleteBook(String bookId, String bookName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text(
          'คุณต้องการลบสมุดบัญชี "$bookName" หรือไม่?\n\nธุรกรรมทั้งหมดในสมุดนี้จะถูกลบด้วย',
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
      await BookApiService.deleteBook(bookId);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('ลบสมุดบัญชีสำเร็จ')));
      }
      _loadBooks();
    } catch (e) {
      Logger.error('BooksManagementPage', 'Delete book error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('ลบสมุดบัญชีไม่สำเร็จ')));
      }
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
        title: Text('จัดการสมุดบัญชี', style: TextStyle(color: c.ink)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: _books.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.menu_book_outlined,
                                size: 64,
                                color: c.ink3,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'ยังไม่มีสมุดบัญชี',
                                style: TextStyle(fontSize: 16, color: c.ink3),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _books.length,
                          itemBuilder: (context, index) {
                            final book = _books[index];
                            final isDefault = book['isDefault'] == true;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: c.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDefault ? c.accent : c.border,
                                  width: isDefault ? 2 : 1,
                                ),
                              ),
                              child: ListTile(
                                leading: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: c.surface2,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: Text(
                                      book['icon'] ?? '📔',
                                      style: const TextStyle(fontSize: 24),
                                    ),
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        book['name'] ?? '',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: c.ink,
                                        ),
                                      ),
                                    ),
                                    if (isDefault)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: c.accent.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          'ค่าเริ่มต้น',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: c.accent,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                subtitle: Text(
                                  'สี: ${book['color'] ?? 'violet'}',
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
                                          _openBookForm(book: book),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.delete_outline,
                                        size: 20,
                                        color: c.coral,
                                      ),
                                      onPressed: () => _deleteBook(
                                        book['id'],
                                        book['name'] ?? '',
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
        heroTag: 'fab_books',
        onPressed: () => _openBookForm(),
        backgroundColor: c.accent,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'สร้างสมุดบัญชี',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}

class _BookFormModal extends StatefulWidget {
  final Map<String, dynamic>? book;

  const _BookFormModal({this.book});

  @override
  State<_BookFormModal> createState() => _BookFormModalState();
}

class _BookFormModalState extends State<_BookFormModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  String _selectedIcon = '📔';
  String _selectedColor = 'violet';
  bool _isDefault = false;
  bool _isSubmitting = false;

  final List<String> _icons = [
    '📔',
    '📕',
    '📗',
    '📘',
    '📙',
    '📓',
    '📒',
    '💰',
    '💳',
    '🏦',
    '💵',
    '💴',
    '💶',
    '💷',
  ];
  final List<Map<String, dynamic>> _colors = [
    {'name': 'violet', 'color': const Color(0xFF8B5CF6)},
    {'name': 'blue', 'color': const Color(0xFF3B82F6)},
    {'name': 'green', 'color': const Color(0xFF10B981)},
    {'name': 'yellow', 'color': const Color(0xFFF59E0B)},
    {'name': 'red', 'color': const Color(0xFFEF4444)},
    {'name': 'pink', 'color': const Color(0xFFEC4899)},
    {'name': 'indigo', 'color': const Color(0xFF6366F1)},
    {'name': 'teal', 'color': const Color(0xFF14B8A6)},
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.book?['name'] ?? '');
    if (widget.book != null) {
      _selectedIcon = widget.book!['icon'] ?? '📔';
      _selectedColor = widget.book!['color'] ?? 'violet';
      _isDefault = widget.book!['isDefault'] ?? false;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final userId = await UserSession.getUserId();
      if (userId == null) throw Exception('ไม่พบ userId');

      if (widget.book != null) {
        // Update
        await BookApiService.updateBook(
          widget.book!['id'],
          name: _nameController.text.trim(),
          icon: _selectedIcon,
          color: _selectedColor,
          isDefault: _isDefault,
        );
      } else {
        // Create
        await BookApiService.createBook(
          userId: userId,
          name: _nameController.text.trim(),
          icon: _selectedIcon,
          color: _selectedColor,
          isDefault: _isDefault,
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.book != null
                  ? 'แก้ไขสมุดบัญชีสำเร็จ'
                  : 'สร้างสมุดบัญชีสำเร็จ',
            ),
          ),
        );
      }
    } catch (e) {
      Logger.error('BooksManagementPage', 'Submit book error: $e');
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
                  widget.book != null ? 'แก้ไขสมุดบัญชี' : 'สร้างสมุดบัญชีใหม่',
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
                    labelText: 'ชื่อสมุดบัญชี',
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
                      return 'กรุณาระบุชื่อสมุดบัญชี';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Icon selector
                Text(
                  'เลือกไอคอน',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: c.ink2,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _icons.map((icon) {
                    final isSelected = _selectedIcon == icon;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedIcon = icon),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: isSelected ? c.accent : c.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? c.accent : c.border,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            icon,
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Color selector
                Text(
                  'เลือกสี',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: c.ink2,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _colors.map((colorData) {
                    final isSelected = _selectedColor == colorData['name'];
                    return GestureDetector(
                      onTap: () =>
                          setState(() => _selectedColor = colorData['name']),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: colorData['color'],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? Colors.white
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 24,
                              )
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Is default
                SwitchListTile(
                  value: _isDefault,
                  onChanged: (value) => setState(() => _isDefault = value),
                  title: Text(
                    'ตั้งเป็นสมุดบัญชีหลัก',
                    style: TextStyle(fontSize: 14, color: c.ink2),
                  ),
                  subtitle: Text(
                    'ใช้เป็นค่าเริ่มต้นเมื่อเพิ่มธุรกรรม',
                    style: TextStyle(fontSize: 12, color: c.ink3),
                  ),
                  contentPadding: EdgeInsets.zero,
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
                                widget.book != null ? 'บันทึก' : 'สร้าง',
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
