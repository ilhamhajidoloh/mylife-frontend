import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// ข้อมูลตัวอย่างจำลองทั้งหมดสำหรับ mockup
/// ในภายหลังส่วนนี้จะถูกแทนที่ด้วยข้อมูลจริงจาก API (back_mylife)

/// ---- KPI ----
class Kpi {
  final String label;
  final String value;
  final String? unit;
  final String delta;
  final bool positive;
  final List<double> spark;
  const Kpi(this.label, this.value,
      {this.unit, required this.delta, required this.positive, this.spark = const []});
}

const kpis = <Kpi>[
  Kpi('ยอดเงินคงเหลือ', '฿68,500',
      delta: '▲ 12%', positive: true, spark: [24, 20, 22, 14, 11, 7, 4]),
  Kpi('ใช้จ่ายเดือนนี้', '฿24,000',
      delta: '▼ 8%', positive: true, spark: [9, 13, 11, 18, 16, 21, 23]),
  Kpi('ก้าวเฉลี่ย / วัน', '7,514',
      delta: '▲ 5%', positive: true, spark: [20, 10, 24, 7, 15, 3, 12]),
  Kpi('งานเสร็จวันนี้', '3 / 5',
      delta: '60%', positive: true),
];

/// ---- การเงิน ----
class MonthFlow {
  final String label;
  final double income; // พันบาท
  final double expense;
  const MonthFlow(this.label, this.income, this.expense);
}

const monthlyFlow = <MonthFlow>[
  MonthFlow('ก.พ.', 45, 32),
  MonthFlow('มี.ค.', 45, 38),
  MonthFlow('เม.ย.', 48, 29),
  MonthFlow('พ.ค.', 45, 41),
  MonthFlow('มิ.ย.', 52, 35),
  MonthFlow('ก.ค.', 45, 30),
];

class ExpenseCat {
  final String emoji;
  final String name;
  final int amount;
  final Color Function(BuildContext) color;
  const ExpenseCat(this.emoji, this.name, this.amount, this.color);
}

final expenseCats = <ExpenseCat>[
  ExpenseCat('🍜', 'อาหาร', 8200, (c) => c.c.accent),
  ExpenseCat('🏠', 'ที่พัก', 6500, (c) => c.c.blue),
  ExpenseCat('🚌', 'เดินทาง', 3400, (c) => c.c.violet),
  ExpenseCat('🛍️', 'ช้อปปิ้ง', 2900, (c) => c.c.amber),
  ExpenseCat('🎬', 'บันเทิง', 1800, (c) => c.c.coral),
  ExpenseCat('📦', 'อื่นๆ', 1200, (c) => c.c.ink3),
];

class SavingsGoal {
  final String title;
  final String due;
  final int saved;
  final int target;
  final int perMonth;
  const SavingsGoal(this.title, this.due, this.saved, this.target, this.perMonth);
  double get progress => saved / target;
  int get remaining => target - saved;
}

const savingsGoal = SavingsGoal('ทริปญี่ปุ่น', 'ธ.ค. 2568', 68500, 100000, 6300);

/// ---- สุขภาพ ----
/// ก้าวเดิน 7 วัน (พันก้าว) จ-อา
const stepDays = <double>[6.2, 8.1, 5.4, 9.3, 7.8, 11.2, 4.6];
const stepGoal = 8.0;
const dayLabels = <String>['จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส', 'อา'];

/// อารมณ์ 7 วัน (1-5)
const moodDays = <double>[3, 4, 2, 4, 5, 5, 3];
const moodEmojis = <String>['😐', '🙂', '😕', '🙂', '😄', '😄', '😐'];

class Habit {
  final String name;
  // true = ทำ, false = พลาด, null = ยังไม่ถึง
  final List<bool?> week;
  const Habit(this.name, this.week);
}

const habits = <Habit>[
  Habit('ออกกำลังกาย', [true, true, false, true, true, true, null]),
  Habit('อ่านหนังสือ', [true, true, true, true, false, true, null]),
  Habit('ดื่มน้ำ 2 ลิตร', [true, false, true, true, true, true, null]),
  Habit('นอนก่อน 23:00', [false, true, true, false, true, false, null]),
];

/// ---- งาน ----
enum TaskState { done, doing, urgent, wait }

class TaskItem {
  final String name;
  final String time;
  final TaskState state;
  const TaskItem(this.name, this.time, this.state);
}

const tasks = <TaskItem>[
  TaskItem('ออกกำลังกาย 30 นาที', '06:30 น.', TaskState.done),
  TaskItem('ประชุมทีมประจำสัปดาห์', '10:00 น.', TaskState.doing),
  TaskItem('ส่งรายงานการเงิน Q2', 'ภายใน 17:00 น.', TaskState.urgent),
  TaskItem('จ่ายค่าน้ำค่าไฟ', '09:15 น.', TaskState.done),
  TaskItem('โทรหาคุณแม่', 'เย็นนี้', TaskState.wait),
];

class EventItem {
  final String day;
  final String month;
  final String name;
  final String meta;
  final Color Function(BuildContext) mark;
  const EventItem(this.day, this.month, this.name, this.meta, this.mark);
}

final events = <EventItem>[
  EventItem('23', 'ก.ค.', 'นัดหมอฟัน', 'พรุ่งนี้ · 14:00 น. · คลินิกสไมล์', (c) => c.c.coral),
  EventItem('25', 'ก.ค.', '🎂 วันเกิดน้องมายด์', 'อีก 3 วัน · เตรียมของขวัญ', (c) => c.c.violet),
  EventItem('28', 'ก.ค.', 'จ่ายค่าบัตรเครดิต', 'อีก 6 วัน · ฿12,400', (c) => c.c.amber),
];

/// ---- ตารางเรียน ----
class Subject {
  final String name;
  final Color Function(BuildContext) color;
  const Subject(this.name, this.color);
}

final subjMath = Subject('คณิตศาสตร์', (c) => c.c.blue);
final subjSci = Subject('วิทยาศาสตร์', (c) => c.c.accent);
final subjEng = Subject('ภาษาอังกฤษ', (c) => c.c.violet);
final subjThai = Subject('ภาษาไทย', (c) => const Color(0xFFC2569B));
final subjHist = Subject('ประวัติศาสตร์', (c) => c.c.amber);
final subjPe = Subject('พลศึกษา', (c) => c.c.coral);
final subjArt = Subject('ศิลปะ', (c) => c.c.good);
final subjComp = Subject('คอมพิวเตอร์', (c) => const Color(0xFF3A8AB5));
final subjClub = Subject('ชมรม', (c) => c.c.ink3);

class ClassSlot {
  final Subject? subject;
  final String room;
  const ClassSlot(this.subject, [this.room = '']);
  static const empty = ClassSlot(null);
}

const periods = <String>[
  '08:30\n09:30',
  '09:30\n10:30',
  '10:30\n11:30',
  '11:30\n12:30',
  '12:30\n13:30',
  '13:30\n14:30',
];

/// index 3 = พักกลางวัน
const lunchPeriod = 3;

/// ตาราง: [period][day] · จ อ พ พฤ ศ ส อา
final timetable = <List<ClassSlot>>[
  [
    ClassSlot(subjMath, 'ห้อง 301'),
    ClassSlot(subjSci, 'แล็บ 2'),
    ClassSlot(subjEng, 'ห้อง 205'),
    ClassSlot(subjHist, 'ห้อง 304'),
    ClassSlot(subjPe, 'สนามกีฬา'),
    ClassSlot.empty,
    ClassSlot.empty,
  ],
  [
    ClassSlot(subjEng, 'ห้อง 205'),
    ClassSlot(subjMath, 'ห้อง 301'),
    ClassSlot(subjSci, 'แล็บ 2'),
    ClassSlot(subjThai, 'ห้อง 208'),
    ClassSlot(subjArt, 'ห้องศิลป์'),
    ClassSlot.empty,
    ClassSlot.empty,
  ],
  [
    ClassSlot(subjSci, 'แล็บ 2'),
    ClassSlot(subjPe, 'สนามกีฬา'),
    ClassSlot(subjMath, 'ห้อง 301'),
    ClassSlot(subjEng, 'ห้อง 205'),
    ClassSlot(subjThai, 'ห้อง 208'),
    ClassSlot.empty,
    ClassSlot.empty,
  ],
  [], // พักกลางวัน
  [
    ClassSlot(subjHist, 'ห้อง 304'),
    ClassSlot(subjEng, 'ห้อง 205'),
    ClassSlot(subjThai, 'ห้อง 208'),
    ClassSlot(subjMath, 'ห้อง 301'),
    ClassSlot(subjSci, 'แล็บ 2'),
    ClassSlot(subjClub, 'ชมรม'),
    ClassSlot.empty,
  ],
  [
    ClassSlot.empty,
    ClassSlot(subjComp, 'ห้องคอม 1'),
    ClassSlot(subjHist, 'ห้อง 304'),
    ClassSlot(subjSci, 'แล็บ 2'),
    ClassSlot(subjClub, 'กิจกรรม'),
    ClassSlot(subjPe, 'สนามกีฬา'),
    ClassSlot.empty,
  ],
];

const scheduleDays = <String>['จันทร์', 'อังคาร', 'พุธ', 'พฤหัส', 'ศุกร์', 'เสาร์', 'อาทิตย์'];

/// วันนี้ = พุธ (index 2)
const todayIndex = 2;

final subjectLegend = <Subject>[
  subjMath, subjSci, subjEng, subjThai, subjHist, subjPe, subjArt, subjComp,
];
