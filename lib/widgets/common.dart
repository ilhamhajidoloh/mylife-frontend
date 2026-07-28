import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SectionCard extends StatelessWidget {
  final String? title;
  final String? caption;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;
  final Gradient? gradient;
  final IconData? icon;
  final Color? iconColor;

  const SectionCard({
    super.key,
    this.title,
    this.caption,
    this.trailing,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(18, 18, 18, 20),
    this.gradient,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? c.surface : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        border: gradient == null ? Border.all(color: c.border.withValues(alpha: 0.4)) : null,
        boxShadow: [
          BoxShadow(
            color: c.accent.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (icon != null) ...[
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: gradient != null ? Colors.white.withValues(alpha: 0.18) : (iconColor ?? c.accent).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 17, color: gradient != null ? Colors.white : (iconColor ?? c.accent)),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title!,
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                              color: gradient != null ? Colors.white : c.ink)),
                      if (caption != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(caption!,
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: gradient != null ? Colors.white.withValues(alpha: 0.8) : c.ink3)),
                        ),
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
          if (title != null) const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class Pill extends StatelessWidget {
  final String text;
  final Color fg;
  final Color bg;
  final Color? border;
  const Pill(this.text, {super.key, required this.fg, required this.bg, this.border});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: border != null ? Border.all(color: border!) : null,
      ),
      child: Text(text,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}

class LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const LegendDot(this.color, this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: context.c.ink2)),
      ],
    );
  }
}

/// Bottom sheet แบบพรีเมียม — มี drag handle, title, animation
Future<T?> showAppBottomSheet<T>(BuildContext context, {
  required String title,
  String? subtitle,
  required Widget child,
  bool isScrollControlled = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    builder: (_) => _AppBottomSheetShell(
      title: title,
      subtitle: subtitle,
      child: child,
    ),
  );
}

class _AppBottomSheetShell extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  const _AppBottomSheetShell({required this.title, this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                  color: c.ink)),
                          if (subtitle != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(subtitle!,
                                  style: TextStyle(fontSize: 13, color: c.ink3)),
                            ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: c.surface2,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.close_rounded, size: 18, color: c.ink3),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    24, 0, 24, MediaQuery.of(context).viewInsets.bottom + 24,
                  ),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dialog แบบพรีเมียม — ใช้แทน AlertDialog ธรรมดา
Future<T?> showAppDialog<T>(BuildContext context, {
  required String title,
  String? subtitle,
  required Widget content,
  List<Widget>? actions,
}) {
  final c = context.c;
  return showDialog<T>(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: c.ink)),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(subtitle, style: TextStyle(fontSize: 13, color: c.ink3)),
                ),
              const SizedBox(height: 20),
              content,
              if (actions != null) ...[
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: actions,
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

/// Input field สำหรับใช้ใน modal — สวยงาม consistent
class AppModalField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData? icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  const AppModalField({
    super.key,
    required this.controller,
    required this.label,
    this.icon,
    this.keyboardType,
    this.obscureText = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: TextStyle(color: c.ink, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: c.ink3),
        prefixIcon: icon != null ? Icon(icon, color: c.ink3, size: 20) : null,
        filled: true,
        fillColor: c.surface2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.accent, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}

/// ปุ่ม action สำหรับ modal — มี gradient variant
class AppModalButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final bool isDestructive;
  const AppModalButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isPrimary = true,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (!isPrimary) {
      return TextButton(
        onPressed: onPressed,
        child: Text(label, style: TextStyle(color: c.ink3, fontWeight: FontWeight.w600)),
      );
    }
    return Container(
      decoration: BoxDecoration(
        gradient: isDestructive ? c.dangerGradient : c.accentGradient,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
      ),
    );
  }
}

/// ไอคอน带队列 style สำหรับใช้ใน modal
class AppModalIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  const AppModalIcon(this.icon, {super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

/// Section หัวข้อย่อยใน modal
class AppModalSection extends StatelessWidget {
  final String title;
  final Widget child;
  const AppModalSection({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: c.ink3,
                letterSpacing: 0.3)),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class PageHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const PageHeader({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.7,
                  color: c.ink)),
          const SizedBox(height: 4),
          Text(subtitle,
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: c.ink3)),
        ],
      ),
    );
  }
}

/// การแสดงผล Skeleton Loader สำหรับสร้างความรู้สึกโหลดข้อมูลอย่างไหลลื่น
class SkeletonCard extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  final EdgeInsets? margin;

  const SkeletonCard({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius = 16,
    this.margin,
  });

  @override
  State<SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<SkeletonCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.35, end: 0.75).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          margin: widget.margin,
          decoration: BoxDecoration(
            color: c.surface.withValues(alpha: _animation.value),
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(color: c.border.withValues(alpha: 0.2)),
          ),
        );
      },
    );
  }
}

/// วิดเจ็ตสำหรับแสดงผลเมื่อกำลังรอดึงข้อมูลหรือเซิร์ฟเวอร์กำลังสตาร์ท (Cold Start)
class ServerConnectingWidget extends StatelessWidget {
  final String? message;
  final String? subMessage;
  final double padding;

  const ServerConnectingWidget({
    super.key,
    this.message,
    this.subMessage,
    this.padding = 32,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Center(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: padding),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: c.border.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(
              color: c.accent.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 54,
                  height: 54,
                  child: CircularProgressIndicator(
                    color: c.accent,
                    strokeWidth: 3.5,
                  ),
                ),
                Icon(
                  Icons.cloud_sync_rounded,
                  color: c.accent,
                  size: 24,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              message ?? 'กำลังเชื่อมต่อเซิร์ฟเวอร์...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: c.ink,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subMessage ?? 'เซิร์ฟเวอร์กำลังเริ่มต้น โปรดรอสักครู่...',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: c.ink3,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Extension ช่วยคำนวณและตรวจสอบขนาดหน้าจอ (Responsive Context)
extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;
  bool get isSmallScreen => screenWidth < 360;
  bool get isTablet => screenWidth >= 600;
  bool get isDesktop => screenWidth >= 900;

  double get responsiveHorizontalPadding {
    if (isSmallScreen) return 12.0;
    if (isTablet) return 24.0;
    return 16.0;
  }
}

/// วิดเจ็ตครอบหน้าจอหลัก ปรับขอบและจำกัดความกว้างสูงสุดบนจอใหญ่ (Tablets / Foldables / Desktop)
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth = 640.0,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final c = context.c;

    if (width <= maxWidth) {
      return child;
    }

    return Container(
      color: c.bg,
      alignment: Alignment.topCenter,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Container(
            decoration: BoxDecoration(
              color: c.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 30,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}


