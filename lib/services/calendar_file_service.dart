import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class CalendarImportEvent {
  final String title;
  final String description;
  final String location;
  final DateTime? start;
  final DateTime? end;
  final bool allDay;
  const CalendarImportEvent({required this.title, required this.description, required this.location, this.start, this.end, required this.allDay});
}

class CalendarFileService {
  static Future<void> exportPdfAndShare(List<dynamic> activities) async {
    final doc = pw.Document();
    final rows = activities.map((item) {
      final start = DateTime.tryParse('${item['startTime'] ?? ''}');
      return [
        start == null ? '-' : '${start.day.toString().padLeft(2, '0')}/${start.month.toString().padLeft(2, '0')}/${start.year}',
        '${item['title'] ?? ''}', '${item['location'] ?? ''}', '${item['description'] ?? ''}',
      ];
    }).toList();
    doc.addPage(pw.MultiPage(pageFormat: PdfPageFormat.a4, build: (_) => [
      pw.Text('MyLife Activities', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 12),
      pw.TableHelper.fromTextArray(headers: ['Date', 'Activity', 'Location', 'Description'], data: rows),
    ]));
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/mylife-activities.pdf');
    await file.writeAsBytes(await doc.save(), flush: true);
    await Share.shareXFiles([XFile(file.path)], subject: 'MyLife activities');
  }
  static Future<void> exportAndShare(List<dynamic> activities) async {
    final lines = <String>['BEGIN:VCALENDAR', 'VERSION:2.0', 'PRODID:-//MyLife//EN', 'CALSCALE:GREGORIAN'];
    for (final item in activities) {
      final start = DateTime.tryParse('${item['startTime'] ?? ''}');
      if (start == null) continue;
      final end = DateTime.tryParse('${item['endTime'] ?? ''}') ?? start.add(const Duration(hours: 1));
      final allDay = item['isAllDay'] == true;
      lines.addAll(['BEGIN:VEVENT', 'UID:${item['id'] ?? DateTime.now().microsecondsSinceEpoch}@mylife', 'DTSTAMP:${_dateTime(DateTime.now().toUtc())}', allDay ? 'DTSTART;VALUE=DATE:${_date(start)}' : 'DTSTART:${_dateTime(start.toUtc())}', allDay ? 'DTEND;VALUE=DATE:${_date(end.add(const Duration(days: 1)))}' : 'DTEND:${_dateTime(end.toUtc())}', 'SUMMARY:${_escape('${item['title'] ?? ''}')}', 'DESCRIPTION:${_escape('${item['description'] ?? ''}')}', 'LOCATION:${_escape('${item['location'] ?? ''}')}', 'END:VEVENT']);
    }
    lines.add('END:VCALENDAR');
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/mylife-activities.ics');
    await file.writeAsString(lines.join('\r\n'));
    await Share.shareXFiles([XFile(file.path)], subject: 'MyLife calendar');
  }

  static Future<List<CalendarImportEvent>?> pickAndParse() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['ics'],
    );
    if (files.isEmpty) return null;
    final bytes = await files.single.readAsBytes();
    return _parse(String.fromCharCodes(bytes));
  }

  static List<CalendarImportEvent> _parse(String source) {
    final unfolded = source.replaceAll(RegExp(r'\r?\n[ \t]'), '');
    final blocks = RegExp(r'BEGIN:VEVENT\s*([\s\S]*?)\s*END:VEVENT', caseSensitive: false).allMatches(unfolded);
    return blocks.map((match) {
      final props = <String, String>{};
      for (final line in match.group(1)!.split(RegExp(r'\r?\n'))) {
        final colon = line.indexOf(':');
        if (colon < 0) continue;
        props[line.substring(0, colon).split(';').first.toUpperCase()] = line.substring(colon + 1);
      }
      final rawStart = props['DTSTART'] ?? '';
      final rawEnd = props['DTEND'];
      final allDay = RegExp(r'^\d{8}$').hasMatch(rawStart);
      final start = _parseDate(rawStart);
      final end = rawEnd == null ? null : _parseDate(rawEnd);
      return CalendarImportEvent(title: _unescape(props['SUMMARY'] ?? 'กิจกรรมจากปฏิทิน'), description: _unescape(props['DESCRIPTION'] ?? ''), location: _unescape(props['LOCATION'] ?? ''), start: start, end: end, allDay: allDay);
    }).where((item) => item.start != null).toList();
  }

  static DateTime? _parseDate(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 8) return null;
    final date = DateTime.tryParse('${digits.substring(0, 4)}-${digits.substring(4, 6)}-${digits.substring(6, 8)}${digits.length >= 12 ? 'T${digits.substring(8, 10)}:${digits.substring(10, 12)}:00' : ''}');
    return value.endsWith('Z') && date != null ? date.toUtc().toLocal() : date;
  }
  static String _date(DateTime value) => '${value.year.toString().padLeft(4, '0')}${value.month.toString().padLeft(2, '0')}${value.day.toString().padLeft(2, '0')}';
  static String _dateTime(DateTime value) => '${_date(value)}T${value.hour.toString().padLeft(2, '0')}${value.minute.toString().padLeft(2, '0')}${value.second.toString().padLeft(2, '0')}Z';
  static String _escape(String value) => value.replaceAll('\\', '\\\\').replaceAll('\n', '\\n').replaceAll(';', '\\;').replaceAll(',', '\\,');
  static String _unescape(String value) => value.replaceAll('\\n', '\n').replaceAll('\\,', ',').replaceAll('\\;', ';').replaceAll('\\\\', '\\');
}
