import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/charts.dart';
import '../services/api_client.dart';
import '../services/api_services.dart';
import '../services/user_session.dart';
import '../services/cache_service.dart';
import '../services/logger.dart';
import '../services/notification_service.dart';
import '../services/data_event_service.dart';

class FinancePage extends StatefulWidget {
  const FinancePage({super.key});

  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage> {
  bool _isLoading = true;

  double _totalIncome = 0.0;
  double _totalExpense = 0.0;
  double _netBalance = 0.0;
  bool _isLowBalance = false;

  List<dynamic> _transactions = [];
  List<dynamic> _top5Expenses = [];
  List<dynamic> _remainingExpenses = [];

  List<dynamic> _recurringExpenses = [];

  String _breakdownPeriod = 'monthly';
  List<dynamic> _breakdownData = [];
  int _breakdownYear = DateTime.now().year;
  int _breakdownMonth = DateTime.now().month;
  bool _isBreakdownLoading = true;

  StreamSubscription<void>? _dataSubscription;

  @override
  void initState() {
    super.initState();
    _loadFinanceData();
    _loadRecurring();
    _loadBreakdown();
    _dataSubscription = DataEventService.onDataChanged.listen((_) {
      if (mounted) {
        _loadFinanceData();
        _loadRecurring();
        _loadBreakdown();
      }
    });
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadFinanceData() async {
    final userId = await UserSession.getUserId();

    // 1. อ่านข้อมูลจาก Cache ก่อนทันทีเพื่อการตอบสนองที่รวดเร็ว
    final cachedSummary = await CacheService.get(userId, CacheService.financeSummary);
    if (cachedSummary != null) {
      _totalIncome = (cachedSummary['totalIncome'] as num?)?.toDouble() ?? 0.0;
      _totalExpense = (cachedSummary['totalExpense'] as num?)?.toDouble() ?? 0.0;
      _netBalance = (cachedSummary['netBalance'] as num?)?.toDouble() ?? 0.0;
      _isLowBalance = cachedSummary['isLowBalance'] == true;
      _top5Expenses = cachedSummary['top5Expenses'] ?? [];
      _remainingExpenses = cachedSummary['remainingExpenses'] ?? [];
    }

    final cachedList = await CacheService.get(userId, CacheService.finance);
    if (cachedList != null) _transactions = cachedList;

    if (cachedSummary != null || cachedList != null) {
      if (mounted) setState(() => _isLoading = false);
    } else {
      if (mounted) setState(() => _isLoading = true);
    }

    try {
      final summary = await FinanceApiService.getSummary(userId);
      if (summary != null) {
        _totalIncome = (summary['totalIncome'] as num?)?.toDouble() ?? 0.0;
        _totalExpense = (summary['totalExpense'] as num?)?.toDouble() ?? 0.0;
        _netBalance = (summary['netBalance'] as num?)?.toDouble() ?? 0.0;
        _isLowBalance = summary['isLowBalance'] == true;
        _top5Expenses = summary['top5Expenses'] ?? [];
        _remainingExpenses = summary['remainingExpenses'] ?? [];
        await CacheService.save(userId, CacheService.financeSummary, summary);
        await _checkLowBalanceNotification(_isLowBalance);
      }

      final list = await FinanceApiService.getTransactions(userId);
      if (list != null) {
        _transactions = list;
        await CacheService.save(userId, CacheService.finance, list);
      }
    } catch (e, st) {
      Logger.catchBlock('FinancePage', 'loadFinanceData', e, st);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// แจ้งเตือนเมื่อเงินคงเหลือต่ำกว่า 0.5% ของรายรับทั้งหมด — จำกัดไว้วันละ 1 ครั้งกันแจ้งซ้ำถี่เกินไป
  Future<void> _checkLowBalanceNotification(bool isLowBalance) async {
    if (!isLowBalance) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final todayKey = '${now.year}-${now.month}-${now.day}';
      final lastNotified = prefs.getString('low_balance_notif_date');
      if (lastNotified == todayKey) return;

      await NotificationService.showInstantNotification(
        id: 84031975,
        title: '⚠️ เงินคงเหลือใกล้หมด',
        body: 'เงินคงเหลือของคุณต่ำกว่า 0.5% ของรายรับทั้งหมดแล้ว ลองตรวจสอบรายจ่ายของคุณ',
      );
      await prefs.setString('low_balance_notif_date', todayKey);
    } catch (e, st) {
      Logger.catchBlock('FinancePage', 'checkLowBalanceNotification', e, st);
    }
  }

  Future<void> _loadRecurring() async {
    final userId = await UserSession.getUserId();

    final cached = await CacheService.get(userId, CacheService.financeRecurring);
    if (cached != null && mounted) setState(() => _recurringExpenses = cached);

    try {
      final list = await FinanceApiService.getRecurring(userId);
      if (list != null) {
        if (mounted) setState(() => _recurringExpenses = list);
        await CacheService.save(userId, CacheService.financeRecurring, list);
      }
    } catch (e, st) {
      Logger.catchBlock('FinancePage', 'loadRecurring', e, st);
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
      Logger.catchBlock('FinancePage', 'loadBreakdown', e, st);
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

  void _openTransactionModal([dynamic item]) {
    final isEdit = item != null;
    final categoryController = TextEditingController(text: item?['category'] ?? '');
    final titleController = TextEditingController(text: item?['note'] ?? '');
    final amountController = TextEditingController(text: item?['amount'] != null ? (item!['amount'] as num).toString() : '');
    bool isIncome = isEdit ? (item?['type'] == 0) : false;

    showAppBottomSheet(
      context,
      title: isEdit ? 'แก้ไขรายการ' : 'เพิ่มรายการ',
      subtitle: 'รายรับ - รายจ่าย',
      child: StatefulBuilder(
        builder: (context, setModalState) {
          final cc = context.c;

          final defaultExpenseCategories = ['อาหาร', 'เดินทาง', 'ช้อปปิ้ง', 'ค่าใช้จ่ายบ้าน', 'บันเทิง', 'สุขภาพ', 'การศึกษา', 'ทั่วไป'];
          final defaultIncomeCategories = ['เงินเดือน', 'โบนัส', 'ธุรกิจส่วนตัว', 'การลงทุน', 'ของขวัญ', 'ทั่วไป'];

          final baseList = isIncome ? defaultIncomeCategories : defaultExpenseCategories;
          final existingCats = _transactions
              .where((t) => (isIncome ? t['type'] == 0 : t['type'] == 1) && t['category'] != null && t['category'].toString().trim().isNotEmpty)
              .map((t) => t['category'].toString().trim())
              .toSet();
          final allCategorySuggestions = {...baseList, ...existingCats}.toList();

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Income/Expense Toggle
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: cc.surface2,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setModalState(() => isIncome = false),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: !isIncome ? cc.coral : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('รายจ่าย',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: !isIncome ? Colors.white : cc.ink3)),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setModalState(() => isIncome = true),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isIncome ? cc.good : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('รายรับ',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: isIncome ? Colors.white : cc.ink3)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Category Field
              AppModalField(controller: categoryController, label: 'หมวดหมู่ (เลือกหรือพิมพ์สร้างใหม่)', icon: Icons.category_rounded),
              const SizedBox(height: 8),

              // Category Chips / Suggestions
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: allCategorySuggestions.map((cat) {
                    final selected = categoryController.text.trim() == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(cat, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? Colors.white : cc.ink2)),
                        selected: selected,
                        selectedColor: isIncome ? cc.good : cc.coral,
                        backgroundColor: cc.surface2,
                        onSelected: (val) {
                          setModalState(() {
                            categoryController.text = val ? cat : '';
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 14),

              // Title / Note Field
              AppModalField(controller: titleController, label: 'ชื่อรายการ / หมายเหตุ', icon: Icons.receipt_rounded),
              const SizedBox(height: 12),

              // Amount Field
              AppModalField(controller: amountController, label: 'จำนวนเงิน (บาท)', icon: Icons.payments_rounded, keyboardType: TextInputType.number),
              const SizedBox(height: 24),

              Row(
                children: [
                  if (isEdit) ...[
                    GestureDetector(
                      onTap: () => _confirmDeleteTransaction(item, context),
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
                      isDestructive: !isIncome,
                      onPressed: () async {
                        final amt = double.tryParse(amountController.text) ?? 0;
                        if (amt <= 0) return;

                        final categoryText = categoryController.text.trim().isEmpty ? 'ทั่วไป' : categoryController.text.trim();
                        final noteText = titleController.text.trim().isEmpty ? categoryText : titleController.text.trim();
                        final userId = await UserSession.getUserId();

                        if (isEdit && item?['id'] != null) {
                          DateTime? origDate;
                          if (item['transactionDate'] != null) {
                            origDate = DateTime.tryParse(item['transactionDate']);
                          }
                          await FinanceApiService.updateTransaction(
                            item['id'].toString(),
                            userId,
                            amt,
                            isIncome,
                            categoryText,
                            noteText,
                            transactionDate: origDate,
                          );
                        } else {
                          await FinanceApiService.addTransaction(userId, amt, isIncome, categoryText, noteText);
                        }
                        if (context.mounted) Navigator.pop(context);
                        _loadFinanceData();
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

  void _confirmDeleteTransaction(dynamic item, BuildContext parentContext) {
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
              Text('ลบรายการนี้?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c.ink)),
              const SizedBox(height: 6),
              Text(
                'ต้องการลบรายการ "${item['note'] ?? item['category'] ?? ''}" ออกใช่หรือไม่?',
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
                          await FinanceApiService.deleteTransaction(item['id'].toString());
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (parentContext.mounted) Navigator.pop(parentContext);
                        _loadFinanceData();
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

  void _openRemainingExpensesModal() {
    showAppBottomSheet(
      context,
      title: 'รายจ่ายทั้งหมด',
      subtitle: 'เรียงจากมากไปน้อย',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < _remainingExpenses.length; i++) ...[
            Builder(builder: (context) {
              final cc = context.c;
              final rank = i + 6;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(color: cc.surface2, borderRadius: BorderRadius.circular(10)),
                      child: Center(child: Text('$rank', style: TextStyle(color: cc.ink3, fontWeight: FontWeight.w800, fontSize: 13))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_remainingExpenses[i]['category'] ?? '', style: TextStyle(fontWeight: FontWeight.w600, color: cc.ink))),
                    Text('฿${(_remainingExpenses[i]['amount'] as num).toStringAsFixed(0)}',
                        style: TextStyle(fontWeight: FontWeight.w800, color: cc.ink2, fontSize: 14)),
                  ],
                ),
              );
            }),
            if (i < _remainingExpenses.length - 1) Divider(height: 1, color: context.c.border.withValues(alpha: 0.5)),
          ],
        ],
      ),
    );
  }

  void _openRecurringModal([dynamic item]) {
    final isEdit = item != null;
    final titleController = TextEditingController(text: item?['title'] ?? '');
    final amountController = TextEditingController(text: item?['amount'] != null ? (item!['amount'] as num).toString() : '');
    int dayOfMonth = (item?['dayOfMonthDue'] as num?)?.toInt() ?? 1;
    bool isIndefinite = isEdit ? (item?['isIndefinite'] ?? true) : true;
    DateTime startDate = isEdit && item['startDate'] != null ? DateTime.parse(item['startDate']) : DateTime.now();
    DateTime? endDate = isEdit && item['endDate'] != null ? DateTime.parse(item['endDate']) : null;

    showAppBottomSheet(
      context,
      title: isEdit ? 'แก้ไขรายการจ่ายประจำ' : 'เพิ่มรายการจ่ายประจำ',
      subtitle: 'รายจ่ายที่เกิดขึ้นซ้ำทุกเดือน',
      child: StatefulBuilder(
        builder: (context, setModalState) {
          final cc = context.c;
          String fmtDate(DateTime d) => '${d.day}/${d.month}/${d.year + 543}';

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppModalField(controller: titleController, label: 'ชื่อรายการ เช่น ค่าเน็ต, ค่าเช่าหอ', icon: Icons.receipt_long_rounded),
              const SizedBox(height: 12),
              AppModalField(controller: amountController, label: 'จำนวนเงิน (บาท)', icon: Icons.payments_rounded, keyboardType: TextInputType.number),
              const SizedBox(height: 18),
              AppModalSection(
                title: 'วันที่ต้องจ่ายทุกเดือน',
                child: SizedBox(
                  height: 84,
                  child: GridView.builder(
                    scrollDirection: Axis.horizontal,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 6, crossAxisSpacing: 6),
                    itemCount: 31,
                    itemBuilder: (context, i) {
                      final day = i + 1;
                      final selected = dayOfMonth == day;
                      return GestureDetector(
                        onTap: () => setModalState(() => dayOfMonth = day),
                        child: Container(
                          width: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: selected ? cc.accent : cc.surface2,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text('$day', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: selected ? Colors.white : cc.ink2)),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 18),
              AppModalSection(
                title: 'ระยะเวลา',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(() => isIndefinite = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isIndefinite ? cc.accent : cc.surface2,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text('ไม่มีกำหนดสิ้นสุด',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: isIndefinite ? Colors.white : cc.ink3)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(() => isIndefinite = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: !isIndefinite ? cc.accent : cc.surface2,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text('มีวันสิ้นสุด',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: !isIndefinite ? Colors.white : cc.ink3)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: startDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) setModalState(() => startDate = picked);
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(color: cc.surface2, borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today_rounded, size: 16, color: cc.ink3),
                            const SizedBox(width: 10),
                            Text('เริ่ม: ${fmtDate(startDate)}', style: TextStyle(fontWeight: FontWeight.w600, color: cc.ink)),
                          ],
                        ),
                      ),
                    ),
                    if (!isIndefinite) ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: endDate ?? startDate,
                            firstDate: startDate,
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) setModalState(() => endDate = picked);
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(color: cc.surface2, borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            children: [
                              Icon(Icons.event_busy_rounded, size: 16, color: cc.ink3),
                              const SizedBox(width: 10),
                              Text(
                                endDate != null ? 'สิ้นสุด: ${fmtDate(endDate!)}' : 'เลือกวันที่สิ้นสุด',
                                style: TextStyle(fontWeight: FontWeight.w600, color: cc.ink),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  if (isEdit) ...[
                    GestureDetector(
                      onTap: () => _confirmDeleteRecurring(item, context),
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
                        final amt = double.tryParse(amountController.text) ?? 0;
                        if (titleController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('กรุณากรอกชื่อรายการ')),
                          );
                          return;
                        }
                        if (amt <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('กรุณากรอกจำนวนเงินให้ถูกต้อง')),
                          );
                          return;
                        }
                        if (!isIndefinite && endDate == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('กรุณาเลือกวันที่สิ้นสุด')),
                          );
                          return;
                        }
                        try {
                          final userId = await UserSession.getUserId();
                          if (isEdit && item?['id'] != null) {
                            await FinanceApiService.updateRecurring(
                              item['id'].toString(), userId, titleController.text.trim(), amt, 'ค่าใช้จ่ายประจำ',
                              startDate, isIndefinite ? null : endDate, isIndefinite, dayOfMonth,
                            );
                          } else {
                            await FinanceApiService.addRecurring(
                              userId, titleController.text.trim(), amt, 'ค่าใช้จ่ายประจำ',
                              startDate, isIndefinite ? null : endDate, isIndefinite, dayOfMonth,
                            );
                          }
                          if (context.mounted) Navigator.pop(context);
                          _loadRecurring();
                          DataEventService.notifyDataChanged();
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('บันทึกไม่สำเร็จ: ${e.toString().replaceAll("Exception: ", "")}')),
                            );
                          }
                        }
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

  void _confirmDeleteRecurring(dynamic item, BuildContext parentContext) {
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
              Text('ลบรายการจ่ายประจำนี้?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c.ink)),
              const SizedBox(height: 6),
              Text(
                'ต้องการลบรายการ "${item['title'] ?? ''}" ออกใช่หรือไม่?',
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
                          await FinanceApiService.deleteRecurring(item['id'].toString());
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (parentContext.mounted) Navigator.pop(parentContext);
                        _loadRecurring();
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
          onPressed: _openTransactionModal,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text('เพิ่มรายการ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadFinanceData,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
          children: [
            const PageHeader(title: 'รายรับรายจ่าย', subtitle: 'จัดการการเงินของคุณ'),
            const SizedBox(height: 16),

            if (_isLowBalance)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: c.dangerGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_rounded, color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'เงินคงเหลือต่ำกว่า 0.5% ของรายรับทั้งหมด!',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

            if (_isLoading) ...[
              ValueListenableBuilder<bool>(
                valueListenable: ApiClient.isConnectingLong,
                builder: (context, isLong, child) {
                  return ServerConnectingWidget(
                    message: isLong ? 'กำลังปลุกเซิร์ฟเวอร์...' : 'กำลังดึงรายการการเงิน...',
                    subMessage: isLong
                        ? 'เซิร์ฟเวอร์กำลังสตาร์ทขึ้นมาใหม่เนื่องจากไม่ได้ใช้งาน โปรดรอสักครู่...'
                        : 'กำลังดึงข้อมูลสรุปรายรับรายจ่ายของคุณ...',
                  );
                },
              ),
              const SizedBox(height: 16),
              const SkeletonCard(height: 100, borderRadius: 20),
            ]
            else ...[
              // Summary Cards
              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      label: 'รายรับ',
                      amount: _totalIncome,
                      icon: Icons.arrow_upward_rounded,
                      colors: [c.good, c.good.withValues(alpha: 0.85)],
                      glowColor: c.good,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      label: 'รายจ่าย',
                      amount: _totalExpense,
                      icon: Icons.arrow_downward_rounded,
                      colors: null,
                      gradient: c.dangerGradient,
                      glowColor: c.coral,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Net balance card
              SectionCard(
                title: 'เงินคงเหลือ',
                icon: Icons.account_balance_wallet_rounded,
                iconColor: _netBalance >= 0 ? c.good : c.coral,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('฿${_netBalance.toStringAsFixed(2)}',
                            style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                                color: _netBalance >= 0 ? c.good : c.coral)),
                        Icon(
                          _netBalance >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                          color: _netBalance >= 0 ? c.good : c.coral,
                          size: 28,
                        ),
                      ],
                    ),
                    if (_totalIncome > 0) ...[
                      const SizedBox(height: 14),
                      Builder(builder: (context) {
                        final ratio = (_totalExpense / _totalIncome).clamp(0.0, 1.0);
                        final barColor = ratio >= 0.9 ? c.coral : (ratio >= 0.7 ? c.amber : c.good);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                height: 8,
                                color: c.surface2,
                                child: FractionallySizedBox(
                                  widthFactor: ratio,
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(colors: [barColor, barColor.withValues(alpha: 0.8)]),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text('ใช้จ่ายไปแล้ว ${(ratio * 100).toStringAsFixed(0)}% ของรายรับ',
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: c.ink3)),
                          ],
                        );
                      }),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Top 5 Expenses
              SectionCard(
                title: 'รายจ่ายสูงสุด 5 อันดับ',
                caption: 'ทั้งหมด',
                icon: Icons.leaderboard_rounded,
                iconColor: c.coral,
                trailing: _remainingExpenses.isNotEmpty
                    ? GestureDetector(
                        onTap: _openRemainingExpensesModal,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: c.accentSoft,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('ดูทั้งหมด ${_remainingExpenses.length}', style: TextStyle(color: c.accent, fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                      )
                    : null,
                child: _top5Expenses.isNotEmpty
                    ? Builder(builder: (context) {
                        final topAmount = (_top5Expenses[0]['amount'] as num).toDouble();
                        return Column(
                          children: [
                            for (var i = 0; i < _top5Expenses.length; i++) ...[
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 26,
                                    height: 26,
                                    margin: const EdgeInsets.only(top: 2),
                                    decoration: BoxDecoration(
                                      color: c.coralSoft,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Text('${i + 1}', style: TextStyle(color: c.coral, fontWeight: FontWeight.w800, fontSize: 12.5)),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: CategoryBar(
                                      label: _top5Expenses[i]['category'] ?? '',
                                      amount: '฿${(_top5Expenses[i]['amount'] as num).toStringAsFixed(0)}',
                                      fraction: topAmount > 0 ? (_top5Expenses[i]['amount'] as num) / topAmount : 0.0,
                                      color: c.coral,
                                    ),
                                  ),
                                ],
                              ),
                              if (i < _top5Expenses.length - 1) const SizedBox(height: 14),
                            ],
                          ],
                        );
                      })
                    : Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('ยังไม่มีข้อมูลรายจ่าย', style: TextStyle(color: c.ink3)),
                      ),
              ),
              const SizedBox(height: 16),

              // Breakdown: daily/monthly/yearly income vs expense
              _buildBreakdownSection(c),
              const SizedBox(height: 16),

              // Recent Transactions
              SectionCard(
                title: 'ธุรกรรมล่าสุด',
                icon: Icons.receipt_long_rounded,
                child: _transactions.isNotEmpty
                    ? Column(
                        children: [
                          for (var t in _transactions.take(10)) ...[
                            GestureDetector(
                              onTap: () => _openTransactionModal(t),
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: (t['type'] == 0 ? c.good : c.coral).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        t['type'] == 0 ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                        color: t['type'] == 0 ? c.good : c.coral,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(t['note'] ?? t['category'] ?? '', style: TextStyle(fontWeight: FontWeight.w600, color: c.ink)),
                                          Text(t['category'] ?? '', style: TextStyle(fontSize: 12, color: c.ink3)),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '฿${(t['amount'] as num).toStringAsFixed(0)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: t['type'] == 0 ? c.good : c.coral,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(Icons.chevron_right_rounded, size: 18, color: c.ink3),
                                  ],
                                ),
                              ),
                            ),
                            if (t != _transactions.take(10).last)
                              Divider(height: 1, color: c.border.withValues(alpha: 0.5)),
                          ],
                        ],
                      )
                    : Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('ยังไม่มีธุรกรรม กด + เพื่อเพิ่มรายการแรก', style: TextStyle(color: c.ink3)),
                      ),
              ),
              const SizedBox(height: 16),

              // Recurring bills
              _buildRecurringSection(c),
            ],
          ],
        ),
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
      title: 'สรุปรายรับ-รายจ่ายตามช่วงเวลา',
      caption: 'เปรียบเทียบรายรับ-รายจ่าย',
      icon: Icons.insights_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Period toggle chips
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

          // Range navigator (not shown for yearly, since it always shows all years)
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
              height: 168,
            ),
            const SizedBox(height: 16),
            Divider(height: 1, color: c.border.withValues(alpha: 0.5)),
            const SizedBox(height: 8),
            SizedBox(
              height: 220,
              child: ListView.separated(
                itemCount: _breakdownData.length,
                separatorBuilder: (_, _) => Divider(height: 1, color: c.border.withValues(alpha: 0.5)),
                itemBuilder: (context, i) {
                  final row = _breakdownData[i];
                  final income = (row['income'] as num).toDouble();
                  final expense = (row['expense'] as num).toDouble();
                  final net = income - expense;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Row(
                      children: [
                        SizedBox(width: 36, child: Text('${row['label']}', style: TextStyle(fontWeight: FontWeight.w700, color: c.ink, fontSize: 13))),
                        Expanded(
                          child: Text('+฿${income.toStringAsFixed(0)}',
                              textAlign: TextAlign.right, style: TextStyle(color: c.good, fontWeight: FontWeight.w600, fontSize: 12.5)),
                        ),
                        Expanded(
                          child: Text('-฿${expense.toStringAsFixed(0)}',
                              textAlign: TextAlign.right, style: TextStyle(color: c.coral, fontWeight: FontWeight.w600, fontSize: 12.5)),
                        ),
                        Expanded(
                          child: Text('฿${net.toStringAsFixed(0)}',
                              textAlign: TextAlign.right,
                              style: TextStyle(color: net >= 0 ? c.ink : c.coral, fontWeight: FontWeight.w800, fontSize: 12.5)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecurringSection(AppColors c) {
    final fixed = _recurringExpenses.where((r) => r['isIndefinite'] != true).toList();
    final indefinite = _recurringExpenses.where((r) => r['isIndefinite'] == true).toList();

    Widget buildRow(dynamic r) {
      final day = (r['dayOfMonthDue'] as num?)?.toInt() ?? 1;
      final startDate = r['startDate'] != null ? DateTime.parse(r['startDate']) : null;
      final endDate = r['endDate'] != null ? DateTime.parse(r['endDate']) : null;
      String rangeText = '';
      if (startDate != null) {
        rangeText = endDate != null
            ? '${startDate.day}/${startDate.month}/${startDate.year + 543} - ${endDate.day}/${endDate.month}/${endDate.year + 543}'
            : 'เริ่ม ${startDate.day}/${startDate.month}/${startDate.year + 543}';
      }

      // คำนวณวันครบกำหนดจ่ายครั้งถัดไป เพื่อแสดงป้ายนับถอยหลัง
      final today = DateTime.now();
      final todayOnly = DateTime(today.year, today.month, today.day);
      DateTime dueDateFor(int year, int month) {
        final daysInMonth = DateTime(year, month + 1, 0).day;
        return DateTime(year, month, day.clamp(1, daysInMonth));
      }

      var nextDue = dueDateFor(today.year, today.month);
      if (nextDue.isBefore(todayOnly)) {
        final nextMonth = today.month == 12 ? 1 : today.month + 1;
        final nextYear = today.month == 12 ? today.year + 1 : today.year;
        nextDue = dueDateFor(nextYear, nextMonth);
      }
      final daysUntil = nextDue.difference(todayOnly).inDays;
      final dueLabel = daysUntil == 0 ? 'ครบกำหนดวันนี้' : 'อีก $daysUntil วัน';
      final Color dueFg = daysUntil == 0 ? c.coral : (daysUntil <= 3 ? c.amber : c.ink3);
      final Color dueBg = daysUntil == 0 ? c.coralSoft : (daysUntil <= 3 ? c.amberSoft : c.surface2);

      return GestureDetector(
        onTap: () => _openRecurringModal(r),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: c.amberSoft, borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.event_repeat_rounded, color: c.amber, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r['title'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w600, color: c.ink)),
                    Text('จ่ายทุกวันที่ $day${rangeText.isNotEmpty ? ' • $rangeText' : ''}',
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: c.ink3)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('฿${(r['amount'] as num).toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.w800, color: c.ink, fontSize: 14)),
                  const SizedBox(height: 4),
                  Pill(dueLabel, fg: dueFg, bg: dueBg),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return SectionCard(
      title: 'รายจ่ายประจำ',
      caption: 'รายการที่ต้องจ่ายทุกเดือน',
      icon: Icons.event_repeat_rounded,
      iconColor: c.amber,
      trailing: GestureDetector(
        onTap: () => _openRecurringModal(),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(gradient: c.accentGradient, borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
        ),
      ),
      child: _recurringExpenses.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Text('ยังไม่มีรายการจ่ายประจำ กด + เพื่อเพิ่ม', style: TextStyle(color: c.ink3)),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (fixed.isNotEmpty) ...[
                  Text('มีกำหนดระยะเวลา', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.ink3, letterSpacing: 0.3)),
                  for (var i = 0; i < fixed.length; i++) ...[
                    buildRow(fixed[i]),
                    if (i < fixed.length - 1) Divider(height: 1, color: c.border.withValues(alpha: 0.5)),
                  ],
                ],
                if (fixed.isNotEmpty && indefinite.isNotEmpty) const SizedBox(height: 12),
                if (indefinite.isNotEmpty) ...[
                  Text('ไม่มีกำหนดสิ้นสุด', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.ink3, letterSpacing: 0.3)),
                  for (var i = 0; i < indefinite.length; i++) ...[
                    buildRow(indefinite[i]),
                    if (i < indefinite.length - 1) Divider(height: 1, color: c.border.withValues(alpha: 0.5)),
                  ],
                ],
              ],
            ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final double amount;
  final IconData icon;
  final List<Color>? colors;
  final Gradient? gradient;
  final Color glowColor;
  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.icon,
    this.colors,
    this.gradient,
    required this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: gradient ?? LinearGradient(colors: colors!, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: glowColor.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -14,
            bottom: -14,
            child: Icon(icon, size: 74, color: Colors.white.withValues(alpha: 0.14)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(9)),
                child: Icon(icon, color: Colors.white, size: 16),
              ),
              const SizedBox(height: 10),
              Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text('฿${amount.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
            ],
          ),
        ],
      ),
    );
  }
}

