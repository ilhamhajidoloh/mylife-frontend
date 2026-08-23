import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'schedule_page.dart';
import 'activity_page.dart';
import 'tasks_page.dart';

class PlannerPage extends StatefulWidget {
  final int initialSubTab;
  const PlannerPage({super.key, this.initialSubTab = 0});

  @override
  State<PlannerPage> createState() => _PlannerPageState();
}

class _PlannerPageState extends State<PlannerPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialSubTab.clamp(0, 2),
    );
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final tabs = [
      {'label': 'ตารางเรียน', 'icon': Icons.calendar_month_rounded},
      {'label': 'กิจกรรม', 'icon': Icons.celebration_rounded},
      {'label': 'งานมอบหมาย', 'icon': Icons.assignment_rounded},
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Segmented Header Switcher
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: c.surface2,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark ? c.border.withValues(alpha: 0.8) : c.border.withValues(alpha: 0.6),
                ),
              ),
              child: Row(
                children: List.generate(tabs.length, (i) {
                  final isSelected = _tabController.index == i;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        _tabController.animateTo(i);
                        setState(() {});
                      },
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: isSelected ? (isDark ? c.surface : Colors.white) : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: isDark ? Colors.black.withValues(alpha: 0.3) : c.ink.withValues(alpha: 0.05),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              tabs[i]['icon'] as IconData,
                              size: 16,
                              color: isSelected ? c.accent : c.ink3,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              tabs[i]['label'] as String,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: isSelected ? c.ink : c.ink3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  SchedulePage(),
                  ActivityPage(),
                  TasksPage(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
