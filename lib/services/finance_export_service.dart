import 'dart:io';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

enum FinanceExportFormat { csv, excel, pdf }
enum FinanceExportScope { month, year, all }

/// Creates a shareable ledger export entirely on-device.  Keeping it here
/// means export still works when the user is reading cached transactions.
class FinanceExportService {
  static Future<void> exportAndShare({
    required List<dynamic> transactions,
    required FinanceExportFormat format,
    required FinanceExportScope scope,
    DateTime? selectedMonth,
    int? selectedYear,
  }) async {
    final now = DateTime.now();
    final filtered = _filter(transactions, scope, selectedMonth ?? now, selectedYear ?? now.year);
    final sorted = [...filtered]..sort((a, b) => _dateOf(a).compareTo(_dateOf(b)));
    final openingBalance = _openingBalance(transactions, scope, selectedMonth ?? now, selectedYear ?? now.year);
    final label = _periodLabel(scope, selectedMonth ?? now, selectedYear ?? now.year);
    final extension = switch (format) {
      FinanceExportFormat.csv => 'csv',
      FinanceExportFormat.excel => 'xlsx',
      FinanceExportFormat.pdf => 'pdf',
    };
    final output = await getTemporaryDirectory();
    final file = File('${output.path}/mylife-finance-${DateFormat('yyyyMMdd-HHmm').format(now)}.$extension');
    final bytes = switch (format) {
      FinanceExportFormat.csv => _csvBytes(sorted, openingBalance),
      FinanceExportFormat.excel => _excelBytes(sorted, openingBalance, label),
      FinanceExportFormat.pdf => await _pdfBytes(sorted, openingBalance, label),
    };
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles([XFile(file.path)], subject: 'MyLife · $label');
  }

  static List<dynamic> _filter(List<dynamic> items, FinanceExportScope scope, DateTime month, int year) =>
      items.where((item) {
        final date = _dateOf(item);
        return switch (scope) {
          FinanceExportScope.month => date.year == month.year && date.month == month.month,
          FinanceExportScope.year => date.year == year,
          FinanceExportScope.all => true,
        };
      }).toList();

  static double _openingBalance(List<dynamic> items, FinanceExportScope scope, DateTime month, int year) {
    if (scope == FinanceExportScope.all) return 0;
    final cutoff = scope == FinanceExportScope.month ? DateTime(month.year, month.month) : DateTime(year);
    return items.where((item) => _dateOf(item).isBefore(cutoff)).fold<double>(0, (sum, item) => sum + _signedAmount(item));
  }

  static DateTime _dateOf(dynamic item) => DateTime.tryParse('${item['transactionDate'] ?? item['entry_date'] ?? item['date'] ?? ''}') ?? DateTime.now();
  static double _amount(dynamic item) => (item['amount'] as num?)?.toDouble() ?? double.tryParse('${item['amount']}') ?? 0;
  static bool _isIncome(dynamic item) {
    final type = item['type'];
    return type == 0 || type == '0' || '$type'.toLowerCase() == 'income';
  }
  static double _signedAmount(dynamic item) => _isIncome(item) ? _amount(item) : -_amount(item);
  static String _periodLabel(FinanceExportScope scope, DateTime month, int year) => switch (scope) {
    FinanceExportScope.month => 'เดือน ${DateFormat('MMMM yyyy', 'th_TH').format(month)}',
    FinanceExportScope.year => 'ปี ${year + 543}',
    FinanceExportScope.all => 'ทุกช่วงเวลา',
  };
  static List<List<dynamic>> _rows(List<dynamic> items, double opening) {
    var balance = opening;
    return items.map((item) {
      balance += _signedAmount(item);
      return [
        DateFormat('dd/MM/yyyy').format(_dateOf(item)),
        _isIncome(item) ? 'รายรับ' : 'รายจ่าย',
        '${item['category'] ?? ''}',
        '${item['note'] ?? item['description'] ?? ''}',
        _amount(item),
        balance,
      ];
    }).toList();
  }
  static Uint8List _csvBytes(List<dynamic> items, double opening) {
    final rows = <List<dynamic>>[
      ['วันที่', 'ประเภท', 'หมวดหมู่', 'รายละเอียด', 'จำนวนเงิน (บาท)', 'คงเหลือสะสม'],
      ['ยอดยกมา', '', '', '', '', opening],
      ..._rows(items, opening),
    ];
    return Uint8List.fromList([0xEF, 0xBB, 0xBF, ...const ListToCsvConverter().convert(rows).codeUnits]);
  }
  static Uint8List _excelBytes(List<dynamic> items, double opening, String label) {
    final excel = Excel.createExcel();
    final sheet = excel['รายรับรายจ่าย'];
    sheet.appendRow([TextCellValue('MyLife · $label')]);
    sheet.appendRow([TextCellValue('วันที่'), TextCellValue('ประเภท'), TextCellValue('หมวดหมู่'), TextCellValue('รายละเอียด'), TextCellValue('จำนวนเงิน (บาท)'), TextCellValue('คงเหลือสะสม')]);
    sheet.appendRow([TextCellValue('ยอดยกมา'), TextCellValue(''), TextCellValue(''), TextCellValue(''), TextCellValue(''), DoubleCellValue(opening)]);
    for (final row in _rows(items, opening)) {
      sheet.appendRow([TextCellValue(row[0]), TextCellValue(row[1]), TextCellValue(row[2]), TextCellValue(row[3]), DoubleCellValue(row[4]), DoubleCellValue(row[5])]);
    }
    return Uint8List.fromList(excel.encode()!);
  }
  static Future<Uint8List> _pdfBytes(List<dynamic> items, double opening, String label) async {
    final doc = pw.Document();
    final rows = _rows(items, opening);
    final income = items.where(_isIncome).fold<double>(0, (sum, item) => sum + _amount(item));
    final expense = items.where((item) => !_isIncome(item)).fold<double>(0, (sum, item) => sum + _amount(item));
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (_) => [
        pw.Text('MyLife Finance · $label', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Text('Opening: ${opening.toStringAsFixed(2)}   Income: ${income.toStringAsFixed(2)}   Expense: ${expense.toStringAsFixed(2)}'),
        pw.SizedBox(height: 16),
        pw.TableHelper.fromTextArray(headers: ['Date', 'Type', 'Category', 'Description', 'Amount', 'Balance'], data: rows.map((r) => [r[0], r[1], r[2], r[3], r[4].toStringAsFixed(2), r[5].toStringAsFixed(2)]).toList()),
      ],
    ));
    return doc.save();
  }
}
