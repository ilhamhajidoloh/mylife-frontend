import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/user_session.dart';
import '../main.dart';

class OnboardingPage extends StatefulWidget {
  final void Function(ThemeMode) onToggleTheme;
  final ThemeMode currentThemeMode;

  const OnboardingPage({
    super.key,
    required this.onToggleTheme,
    required this.currentThemeMode,
  });

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingSlideData> _slides = [
    OnboardingSlideData(
      title: 'จัดการการเงินอย่างชาญฉลาด',
      subtitle: 'บันทึกรายรับ-รายจ่าย ตรวจสอบยอดเงินคงเหลือ และวิเคราะห์งบประมาณของคุณได้อย่างง่ายดาย',
      icon: Icons.account_balance_wallet_rounded,
      badgeText: 'การเงิน & งบประมาณ',
      gradientSupplier: (c) => c.heroGradient,
      accentColorSupplier: (c) => c.accent,
      previewWidgetBuilder: (c) => _buildFinancePreview(c),
    ),
    OnboardingSlideData(
      title: 'ไม่พลาดทุกคาบเรียน',
      subtitle: 'จัดตารางเรียนรายสัปดาห์ กำหนดเวลาภาคเรียน พร้อมรับแจ้งเตือนวิชาเรียนถัดไปทันที',
      icon: Icons.school_rounded,
      badgeText: 'ตารางเรียน & ภาคเรียน',
      gradientSupplier: (c) => LinearGradient(colors: [c.blue, c.accent]),
      accentColorSupplier: (c) => c.blue,
      previewWidgetBuilder: (c) => _buildSchedulePreview(c),
    ),
    OnboardingSlideData(
      title: 'จัดลำดับความสำคัญในชีวิต',
      subtitle: 'บันทึกสิ่งที่ต้องทำ (Todolist) จัดกลุ่มตามแท็ก และติดตามงานส่งตาม Deadline แบบเร่งด่วน',
      icon: Icons.check_circle_rounded,
      badgeText: 'Todolist & งานเร่งด่วน',
      gradientSupplier: (c) => LinearGradient(colors: [c.violet, c.accent]),
      accentColorSupplier: (c) => c.violet,
      previewWidgetBuilder: (c) => _buildTaskPreview(c),
    ),
    OnboardingSlideData(
      title: 'ดูแลสุขภาพและกิจกรรม',
      subtitle: 'นับก้าวเดิน กราฟอัตราการเต้นหัวใจ และสร้าง Timeline กิจกรรมพร้อมเวลานับถอยหลังล่วงหน้า',
      icon: Icons.favorite_rounded,
      badgeText: 'สุขภาพ & กิจกรรม',
      gradientSupplier: (c) => LinearGradient(colors: [c.coral, c.amber]),
      accentColorSupplier: (c) => c.coral,
      previewWidgetBuilder: (c) => _buildHealthPreview(c),
    ),
  ];

  Future<void> _finishOnboarding() async {
    await UserSession.setFirstRunCompleted();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => HomeShell(
          onToggleTheme: widget.onToggleTheme,
          currentThemeMode: widget.currentThemeMode,
        ),
        transitionsBuilder: (_, anim, _, child) => FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  void _nextPage() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finishOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final isLastPage = _currentPage == _slides.length - 1;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar with App Logo and Skip button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          gradient: c.accentGradient,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(color: c.accent.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3)),
                          ],
                        ),
                        child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Mylife',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: c.ink, letterSpacing: -0.5),
                      ),
                    ],
                  ),
                  if (!isLastPage)
                    TextButton(
                      onPressed: _finishOnboarding,
                      style: TextButton.styleFrom(
                        foregroundColor: c.ink3,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      child: const Text('ข้าม', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    )
                  else
                    const SizedBox(height: 36),
                ],
              ),
            ),

            // Page View Content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemCount: _slides.length,
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Micro UI Preview Banner
                        slide.previewWidgetBuilder(c),
                        const SizedBox(height: 36),

                        // Category Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: slide.accentColorSupplier(c).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: slide.accentColorSupplier(c).withValues(alpha: 0.25)),
                          ),
                          child: Text(
                            slide.badgeText,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: slide.accentColorSupplier(c),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Title
                        Text(
                          slide.title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.6,
                            color: c.ink,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Subtitle
                        Text(
                          slide.subtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: c.ink3,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Bottom Navigation Area
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Page Indicators
                  Row(
                    children: List.generate(_slides.length, (idx) {
                      final selected = idx == _currentPage;
                      final accentColor = _slides[_currentPage].accentColorSupplier(c);
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        margin: const EdgeInsets.only(right: 6),
                        width: selected ? 28 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: selected ? accentColor : c.border,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),

                  // Action Button
                  GestureDetector(
                    onTap: _nextPage,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: EdgeInsets.symmetric(horizontal: isLastPage ? 24 : 20, vertical: 14),
                      decoration: BoxDecoration(
                        gradient: _slides[_currentPage].gradientSupplier(c),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: _slides[_currentPage].accentColorSupplier(c).withValues(alpha: 0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Text(
                            isLastPage ? 'เริ่มต้นใช้งาน' : 'ถัดไป',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            isLastPage ? Icons.rocket_launch_rounded : Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Micro-UI Previews
  static Widget _buildFinancePreview(AppColors c) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: c.heroGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: c.accent.withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('ยอดเงินคงเหลือสุทธิ', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)),
                child: const Text('อัพเดทเรียลไทม์', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text('฿45,280.00', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                  child: const Row(
                    children: [
                      Icon(Icons.arrow_upward_rounded, color: Colors.greenAccent, size: 16),
                      SizedBox(width: 6),
                      Text('รายรับ ฿52,000', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                  child: const Row(
                    children: [
                      Icon(Icons.arrow_downward_rounded, color: Colors.orangeAccent, size: 16),
                      SizedBox(width: 6),
                      Text('รายจ่าย ฿6,720', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _buildSchedulePreview(AppColors c) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: c.border),
        boxShadow: [
          BoxShadow(color: c.blue.withValues(alpha: 0.15), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ตารางเรียนวันนี้', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c.ink)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: c.blue.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                child: Text('3 วิชา', style: TextStyle(color: c.blue, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: c.accentSoft.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                Icon(Icons.school_rounded, color: c.accent, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Mobile App Development', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: c.ink)),
                      Text('09:00 - 12:00 น. · ห้อง Lab 402', style: TextStyle(fontSize: 11, color: c.ink3)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(6)),
                  child: const Text('กำลังเรียน', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildTaskPreview(AppColors c) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: c.border),
        boxShadow: [
          BoxShadow(color: c.violet.withValues(alpha: 0.15), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Todolist & งานส่ง', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c.ink)),
              Text('เสร็จสิ้น 80%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: c.good)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(value: 0.8, backgroundColor: c.surface2, valueColor: AlwaysStoppedAnimation(c.accent), minHeight: 8),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.check_circle_rounded, color: c.good, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text('ส่งโปรเจกต์ Final UI Design', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: c.ink))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: c.coralSoft, borderRadius: BorderRadius.circular(6)),
                child: Text('เร่งด่วน', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: c.coral)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _buildHealthPreview(AppColors c) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [c.coral, c.amber]),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: c.coral.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(16)),
            child: const Column(
              children: [
                Icon(Icons.directions_walk_rounded, color: Colors.white, size: 28),
                SizedBox(height: 4),
                Text('8,420 ก้าว', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('กิจกรรมถัดไป', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
                SizedBox(height: 2),
                Text('ออกกำลังกายคาร์ดิโอ', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text('อีก 45 นาที · ฟิตเนสคอนโด', style: TextStyle(color: Colors.white, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingSlideData {
  final String title;
  final String subtitle;
  final IconData icon;
  final String badgeText;
  final Gradient Function(AppColors) gradientSupplier;
  final Color Function(AppColors) accentColorSupplier;
  final Widget Function(AppColors) previewWidgetBuilder;

  OnboardingSlideData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.badgeText,
    required this.gradientSupplier,
    required this.accentColorSupplier,
    required this.previewWidgetBuilder,
  });
}
