import 'package:flutter/material.dart';

@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color bg;
  final Color surface;
  final Color surface2;
  final Color border;
  final Color ink;
  final Color ink2;
  final Color ink3;
  final Color accent;
  final Color accentSoft;
  final Color coral;
  final Color coralSoft;
  final Color amber;
  final Color amberSoft;
  final Color violet;
  final Color blue;
  final Color good;
  final Gradient accentGradient;
  final Gradient heroGradient;
  final Gradient dangerGradient;
  final Gradient purpleGradient;
  final Gradient emeraldGradient;
  final Gradient walletGradient;

  const AppColors({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.border,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.accent,
    required this.accentSoft,
    required this.coral,
    required this.coralSoft,
    required this.amber,
    required this.amberSoft,
    required this.violet,
    required this.blue,
    required this.good,
    required this.accentGradient,
    required this.heroGradient,
    required this.dangerGradient,
    required this.purpleGradient,
    required this.emeraldGradient,
    required this.walletGradient,
  });

  static const light = AppColors(
    bg: Color(0xFFF4F7FB),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFF1F5F9),
    border: Color(0xFFE2E8F0),
    ink: Color(0xFF0F172A),
    ink2: Color(0xFF334155),
    ink3: Color(0xFF64748B),
    accent: Color(0xFF6366F1),
    accentSoft: Color(0xFFEEF2FF),
    coral: Color(0xFFF43F5E),
    coralSoft: Color(0xFFFFF1F2),
    amber: Color(0xFFF59E0B),
    amberSoft: Color(0xFFFEF3C7),
    violet: Color(0xFF8B5CF6),
    blue: Color(0xFF3B82F6),
    good: Color(0xFF10B981),
    accentGradient: LinearGradient(
      colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    heroGradient: LinearGradient(
      colors: [Color(0xFF4F46E5), Color(0xFF7C3AED), Color(0xFF2563EB)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    dangerGradient: LinearGradient(
      colors: [Color(0xFFF43F5E), Color(0xFFE11D48)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    purpleGradient: LinearGradient(
      colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    emeraldGradient: LinearGradient(
      colors: [Color(0xFF10B981), Color(0xFF059669)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    walletGradient: LinearGradient(
      colors: [Color(0xFF1E1B4B), Color(0xFF312E81), Color(0xFF4338CA)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );

  static const dark = AppColors(
    bg: Color(0xFF080C16),
    surface: Color(0xFF0F172A),
    surface2: Color(0xFF1E293B),
    border: Color(0xFF1E293B),
    ink: Color(0xFFF8FAFC),
    ink2: Color(0xFF94A3B8),
    ink3: Color(0xFF64748B),
    accent: Color(0xFF818CF8),
    accentSoft: Color(0xFF1E1B4B),
    coral: Color(0xFFFB7185),
    coralSoft: Color(0xFF37121E),
    amber: Color(0xFFFBBF24),
    amberSoft: Color(0xFF3B2F10),
    violet: Color(0xFFA78BFA),
    blue: Color(0xFF60A5FA),
    good: Color(0xFF34D399),
    accentGradient: LinearGradient(
      colors: [Color(0xFF818CF8), Color(0xFF6366F1)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    heroGradient: LinearGradient(
      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFF38BDF8)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    dangerGradient: LinearGradient(
      colors: [Color(0xFFFB7185), Color(0xFFF43F5E)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    purpleGradient: LinearGradient(
      colors: [Color(0xFFA78BFA), Color(0xFF818CF8)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    emeraldGradient: LinearGradient(
      colors: [Color(0xFF34D399), Color(0xFF10B981)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    walletGradient: LinearGradient(
      colors: [Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF312E81)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );

  @override
  AppColors copyWith({
    Color? bg,
    Color? surface,
    Color? surface2,
    Color? border,
    Color? ink,
    Color? ink2,
    Color? ink3,
    Color? accent,
    Color? accentSoft,
    Color? coral,
    Color? coralSoft,
    Color? amber,
    Color? amberSoft,
    Color? violet,
    Color? blue,
    Color? good,
    Gradient? accentGradient,
    Gradient? heroGradient,
    Gradient? dangerGradient,
    Gradient? purpleGradient,
    Gradient? emeraldGradient,
    Gradient? walletGradient,
  }) {
    return AppColors(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surface2: surface2 ?? this.surface2,
      border: border ?? this.border,
      ink: ink ?? this.ink,
      ink2: ink2 ?? this.ink2,
      ink3: ink3 ?? this.ink3,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      coral: coral ?? this.coral,
      coralSoft: coralSoft ?? this.coralSoft,
      amber: amber ?? this.amber,
      amberSoft: amberSoft ?? this.amberSoft,
      violet: violet ?? this.violet,
      blue: blue ?? this.blue,
      good: good ?? this.good,
      accentGradient: accentGradient ?? this.accentGradient,
      heroGradient: heroGradient ?? this.heroGradient,
      dangerGradient: dangerGradient ?? this.dangerGradient,
      purpleGradient: purpleGradient ?? this.purpleGradient,
      emeraldGradient: emeraldGradient ?? this.emeraldGradient,
      walletGradient: walletGradient ?? this.walletGradient,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surface2: Color.lerp(surface2, other.surface2, t)!,
      border: Color.lerp(border, other.border, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      ink2: Color.lerp(ink2, other.ink2, t)!,
      ink3: Color.lerp(ink3, other.ink3, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      coral: Color.lerp(coral, other.coral, t)!,
      coralSoft: Color.lerp(coralSoft, other.coralSoft, t)!,
      amber: Color.lerp(amber, other.amber, t)!,
      amberSoft: Color.lerp(amberSoft, other.amberSoft, t)!,
      violet: Color.lerp(violet, other.violet, t)!,
      blue: Color.lerp(blue, other.blue, t)!,
      good: Color.lerp(good, other.good, t)!,
      accentGradient: Gradient.lerp(accentGradient, other.accentGradient, t)!,
      heroGradient: Gradient.lerp(heroGradient, other.heroGradient, t)!,
      dangerGradient: Gradient.lerp(dangerGradient, other.dangerGradient, t)!,
      purpleGradient: Gradient.lerp(purpleGradient, other.purpleGradient, t)!,
      emeraldGradient: Gradient.lerp(
        emeraldGradient,
        other.emeraldGradient,
        t,
      )!,
      walletGradient: Gradient.lerp(walletGradient, other.walletGradient, t)!,
    );
  }
}

extension AppColorsX on BuildContext {
  AppColors get c => Theme.of(this).extension<AppColors>()!;
}

String formatMoney(int v) {
  final s = v.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

class AppTheme {
  static ThemeData _base(AppColors c, Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: c.accent,
      brightness: brightness,
    ).copyWith(surface: c.surface, primary: c.accent, error: c.coral);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.bg,
      extensions: [c],
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w900,
          color: c.ink,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: c.ink),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface,
        elevation: 0,
        height: 72,
        indicatorColor: c.accentSoft,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? c.accent : c.ink3,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(color: selected ? c.accent : c.ink3, size: 24);
        }),
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: c.border.withValues(alpha: 0.6)),
        ),
        margin: EdgeInsets.zero,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.accent,
        foregroundColor: Colors.white,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: c.border.withValues(alpha: 0.7)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: c.border.withValues(alpha: 0.7)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: c.accent, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          side: BorderSide(color: c.border),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: c.border.withValues(alpha: 0.6),
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.ink,
        contentTextStyle: TextStyle(
          color: c.surface,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static ThemeData get light => _base(AppColors.light, Brightness.light);
  static ThemeData get dark => _base(AppColors.dark, Brightness.dark);
}
