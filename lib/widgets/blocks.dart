import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../data/sample_data.dart';
import 'common.dart';

class KpiTile extends StatelessWidget {
  final String label;
  final String value;
  final String delta;
  final bool positive;
  final Widget trailing;
  final Gradient? gradient;
  const KpiTile({
    super.key,
    required this.label,
    required this.value,
    required this.delta,
    required this.positive,
    required this.trailing,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final deltaColor = positive ? c.good : c.coral;
    return SectionCard(
      gradient: gradient,
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: gradient != null ? Colors.white.withValues(alpha: 0.8) : c.ink2)),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: gradient != null ? Colors.white : c.ink)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: gradient != null
                      ? Colors.white.withValues(alpha: 0.2)
                      : deltaColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(delta,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: gradient != null ? Colors.white : deltaColor)),
              ),
              trailing,
            ],
          ),
        ],
      ),
    );
  }
}

class MiniProgress extends StatelessWidget {
  final double fraction;
  final Color color;
  final double width;
  const MiniProgress(this.fraction,
      {super.key, required this.color, this.width = 84});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: width,
        height: 8,
        color: c.surface2,
        child: FractionallySizedBox(
          widthFactor: fraction.clamp(0.0, 1.0),
          alignment: Alignment.centerLeft,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withValues(alpha: 0.8)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TaskRow extends StatelessWidget {
  final TaskItem task;
  final bool last;
  const TaskRow(this.task, {super.key, this.last = false});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final done = task.state == TaskState.done;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(bottom: BorderSide(color: c.border.withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              gradient: done
                  ? LinearGradient(colors: [c.accent, c.accent.withValues(alpha: 0.8)])
                  : null,
              color: done ? null : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                  color: done ? c.accent : c.border, width: 2),
            ),
            child: done
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: done ? c.ink3 : c.ink,
                      decoration:
                          done ? TextDecoration.lineThrough : null,
                    )),
                Text(task.time,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.ink3)),
              ],
            ),
          ),
          _statePill(context, task.state),
        ],
      ),
    );
  }

  Widget _statePill(BuildContext context, TaskState s) {
    final c = context.c;
    switch (s) {
      case TaskState.doing:
        return Pill('กำลังทำ', fg: c.accent, bg: c.accentSoft);
      case TaskState.urgent:
        return Pill('เร่งด่วน', fg: c.coral, bg: c.coralSoft);
      case TaskState.wait:
        return Pill('รอ', fg: c.ink3, bg: c.surface2, border: c.border);
      case TaskState.done:
        return const SizedBox.shrink();
    }
  }
}

class EventRow extends StatelessWidget {
  final EventItem event;
  final bool last;
  const EventRow(this.event, {super.key, this.last = false});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: c.border.withValues(alpha: 0.5))),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                  color: event.mark(context),
                  borderRadius: BorderRadius.circular(4)),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 42,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(event.day,
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          height: 1,
                          color: c.ink)),
                  Text(event.month,
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: c.ink3,
                          letterSpacing: 0.4)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.name,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: c.ink)),
                  Text(event.meta,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.ink3)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ตารางเรียนรายสัปดาห์แบบ grid วัน×เวลา — ทุกคอลัมน์ใช้แกนเวลาเดียวกัน
/// เพื่อให้เทียบคาบเรียนที่ตรงกัน/ทับกันระหว่างวันได้ในสายตาเดียว
class TimetableView extends StatelessWidget {
  final List<dynamic> courses;
  const TimetableView({super.key, this.courses = const []});

  static const double _dayW = 108;
  static const double _hourH = 56;
  static const double _hourLabelW = 40;
  static const double _headerH = 28;

  int _hourOf(String? time, int fallback) {
    if (time == null || time.isEmpty) return fallback;
    return int.tryParse(time.split(':')[0]) ?? fallback;
  }

  int _minuteOf(String? time) {
    if (time == null) return 0;
    final parts = time.split(':');
    return parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
  }

  int _parseDayOfWeek(dynamic rawDayVal) {
    if (rawDayVal is int) return rawDayVal;
    if (rawDayVal != null) {
      final str = rawDayVal.toString().toLowerCase().trim();
      final parsed = int.tryParse(str);
      if (parsed != null) return parsed;
      if (str.contains('sun')) return 0;
      if (str.contains('mon')) return 1;
      if (str.contains('tue')) return 2;
      if (str.contains('wed')) return 3;
      if (str.contains('thu')) return 4;
      if (str.contains('fri')) return 5;
      if (str.contains('sat')) return 6;
    }
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    if (courses.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        alignment: Alignment.center,
        child: Column(
          children: [
            Icon(Icons.calendar_today_outlined, size: 38, color: c.ink3.withValues(alpha: 0.4)),
            const SizedBox(height: 10),
            Text('ยังไม่มีข้อมูลวิชาเรียนในสัปดาห์นี้', style: TextStyle(fontWeight: FontWeight.w600, color: c.ink2, fontSize: 13.5)),
            const SizedBox(height: 4),
            Text('กดปุ่ม "+ เพิ่มวิชา" ด้านล่างเพื่อเพิ่มวิชาเรียน', style: TextStyle(fontSize: 12, color: c.ink3)),
          ],
        ),
      );
    }

    // หาช่วงชั่วโมงที่ต้องแสดงจากคาบเรียนจริงทั้งหมด (ปัดขอบให้ครอบคลุมทุกคาบ)
    var minHour = 24, maxHour = 0;
    for (final crs in courses) {
      final startStr = (crs['startTime'] ?? crs['StartTime'])?.toString();
      final endStr = (crs['endTime'] ?? crs['EndTime'])?.toString();
      final sh = _hourOf(startStr, 8);
      final eh = _hourOf(endStr, 9);
      final eMin = _minuteOf(endStr);
      final ceilEndHour = eMin > 0 ? eh + 1 : eh;
      if (sh < minHour) minHour = sh;
      if (ceilEndHour > maxHour) maxHour = ceilEndHour;
    }
    if (minHour >= maxHour) {
      minHour = 8;
      maxHour = 17;
    }
    minHour = minHour.clamp(0, 22);
    maxHour = maxHour.clamp(minHour + 1, 24);
    final hourCount = maxHour - minHour;
    final gridHeight = hourCount * _hourH;

    double minutesFromGridStart(String? time) {
      if (time == null || time.isEmpty) return 0;
      return (_hourOf(time, minHour) - minHour) * 60.0 + _minuteOf(time);
    }

    final daysShort = ['', 'จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส', 'อา'];
    final nowDay = DateTime.now().weekday;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // แกนชั่วโมงด้านซ้าย
        SizedBox(
          width: _hourLabelW,
          child: Column(
            children: [
              const SizedBox(height: _headerH + 4),
              for (var h = minHour; h < maxHour; h++)
                SizedBox(
                  height: _hourH,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Text('$h:00', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: c.ink3)),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(7, (i) {
                final dayNum = i + 1;
                final isToday = dayNum == nowDay;
                final dayCourses = courses.where((crs) {
                  final rawDay = crs['dayOfWeek'] ?? crs['DayOfWeek'];
                  final parsedDay = _parseDayOfWeek(rawDay);
                  final dartDay = (parsedDay == 0) ? 7 : parsedDay;
                  return dartDay == dayNum;
                }).toList();

                return Container(
                  width: _dayW,
                  margin: EdgeInsets.only(right: i < 6 ? 6 : 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        height: _headerH,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isToday ? c.accent : c.surface2,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(daysShort[dayNum],
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: isToday ? Colors.white : c.ink)),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: gridHeight,
                        child: Stack(
                          children: [
                            Column(
                              children: List.generate(
                                hourCount,
                                (_) => Container(
                                  height: _hourH,
                                  decoration: BoxDecoration(border: Border(top: BorderSide(color: c.border.withValues(alpha: 0.4)))),
                                ),
                              ),
                            ),
                            for (final course in dayCourses) _buildCourseBlock(context, course, minutesFromGridStart),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCourseBlock(BuildContext context, dynamic course, double Function(String?) minutesFromGridStart) {
    final c = context.c;
    final name = (course['courseName'] ?? course['CourseName'] ?? course['courseCode'] ?? course['CourseCode'] ?? '').toString();
    final room = (course['room'] ?? course['Room'] ?? '').toString();
    final startTimeStr = (course['startTime'] ?? course['StartTime'])?.toString();
    final endTimeStr = (course['endTime'] ?? course['EndTime'])?.toString();
    final startTime = (startTimeStr ?? '').split(':').take(2).join(':');
    final endTime = (endTimeStr ?? '').split(':').take(2).join(':');
    final palette = [c.blue, c.accent, c.violet, c.amber, c.coral, c.good];
    final courseColor = palette[name.hashCode.abs() % palette.length];

    final startMin = minutesFromGridStart(startTimeStr);
    final endMin = minutesFromGridStart(endTimeStr);
    final top = (startMin / 60.0) * _hourH;
    final height = ((endMin - startMin).clamp(20, 24 * 60) / 60.0) * _hourH;

    return Positioned(
      top: top,
      left: 2,
      right: 2,
      height: height,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: courseColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: courseColor.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(name, maxLines: height > 40 ? 2 : 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: courseColor)),
            if (height > 34) Text('$startTime-$endTime', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9, color: c.ink3)),
            if (height > 50 && room.isNotEmpty)
              Text(room, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9, color: c.ink3)),
          ],
        ),
      ),
    );
  }
}
