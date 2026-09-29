import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'theme/app_theme.dart';
import 'widgets/common.dart';
import 'pages/overview_page.dart';
import 'pages/planner_page.dart';
import 'pages/finance_page.dart';
import 'pages/todolist_page.dart';
import 'pages/auth_page.dart';
import 'pages/onboarding_page.dart';
import 'pages/profile_page.dart';
import 'services/user_session.dart';
import 'services/notification_service.dart';
import 'services/connectivity_service.dart';
import 'services/api_client.dart';
import 'services/api_services.dart';
import 'services/data_event_service.dart';
import 'config/api_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  await NotificationService.init();
  runApp(const MyLifeApp());
}

class MyLifeApp extends StatefulWidget {
  const MyLifeApp({super.key});

  @override
  State<MyLifeApp> createState() => _MyLifeAppState();
}

class _MyLifeAppState extends State<MyLifeApp> {
  ThemeMode _themeMode = ThemeMode.system;
  bool _isFirstRun = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await ConnectivityService.initialize();
    final mode = await UserSession.getThemeMode();
    final firstRun = await UserSession.isFirstRun();
    if (mounted) {
      setState(() {
        switch (mode) {
          case 'light':
            _themeMode = ThemeMode.light;
            break;
          case 'dark':
            _themeMode = ThemeMode.dark;
            break;
          default:
            _themeMode = ThemeMode.system;
        }
        _isFirstRun = firstRun;
        _isLoading = false;
      });
    }
  }

  void _setThemeMode(ThemeMode mode) {
    setState(() => _themeMode = mode);
    String modeStr = 'system';
    if (mode == ThemeMode.light) modeStr = 'light';
    if (mode == ThemeMode.dark) modeStr = 'dark';
    UserSession.saveThemeMode(modeStr);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return MaterialApp(
        title: 'Mylife',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: _themeMode,
        builder: (context, child) =>
            ResponsiveContainer(child: child ?? const SizedBox()),
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MaterialApp(
      title: 'Mylife',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _themeMode,
      builder: (context, child) =>
          ResponsiveContainer(child: child ?? const SizedBox()),
      home: _isFirstRun
          ? OnboardingPage(
              onToggleTheme: _setThemeMode,
              currentThemeMode: _themeMode,
            )
          : HomeShell(
              onToggleTheme: _setThemeMode,
              currentThemeMode: _themeMode,
            ),
    );
  }
}

class HomeShell extends StatefulWidget {
  final void Function(ThemeMode) onToggleTheme;
  final ThemeMode currentThemeMode;
  const HomeShell({
    super.key,
    required this.onToggleTheme,
    required this.currentThemeMode,
  });

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  bool _isChecking = true;
  bool _isLoggedIn = false;
  String _userName = 'โปรไฟล์';
  String? _profileImageUrl;
  bool _isOnline = true;
  bool _plannerEnabled = true;
  bool _financeEnabled = true;
  bool _todosEnabled = true;
  StreamSubscription<bool>? _connectivitySubscription;

  static const _pages = <Widget>[
    OverviewPage(),
    PlannerPage(),
    FinancePage(),
    TodolistPage(),
  ];

  static const _icons = <IconData>[
    Icons.grid_view_rounded,
    Icons.calendar_month_rounded,
    Icons.account_balance_wallet_rounded,
    Icons.checklist_rounded,
  ];

  static const _iconsOut = <IconData>[
    Icons.grid_view_outlined,
    Icons.calendar_month_outlined,
    Icons.account_balance_wallet_outlined,
    Icons.checklist_outlined,
  ];

  @override
  void initState() {
    super.initState();
    _isOnline = ConnectivityService.isOnline;
    ApiClient.setOffline(!_isOnline);
    _connectivitySubscription = ConnectivityService.isOnlineStream.listen((
      isOnline,
    ) {
      if (mounted) {
        setState(() {
          _isOnline = isOnline;
          ApiClient.setOffline(!isOnline);
        });
        if (isOnline) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'กลับมาออนไลน์แล้ว — ดึงหน้าจอเพื่ออัพเดทข้อมูล',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              backgroundColor: Color(0xFF4CAF50),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    });
    _checkInitialLogin();
    _loadModuleVisibility();
  }

  Future<void> _loadModuleVisibility() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _plannerEnabled = prefs.getBool('module_planner') ?? true;
      _financeEnabled = prefs.getBool('module_finance') ?? true;
      _todosEnabled = prefs.getBool('module_todos') ?? true;
      if ((_index == 1 && !_plannerEnabled) || (_index == 2 && !_financeEnabled) || (_index == 3 && !_todosEnabled)) _index = 0;
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkInitialLogin() async {
    setState(() => _isChecking = true);
    final loggedIn = await UserSession.isLoggedIn();
    final name = await UserSession.getUserName();
    final userId = await UserSession.getUserId();

    // ใช้ Backend Streaming URL เสมอ (โหลดได้แน่นอน ไม่ขึ้นอยู่กับ Oracle URL)
    final String? profileImg = (loggedIn && userId.isNotEmpty)
        ? ApiConfig.authProfileImageUrl(userId)
        : null;

    if (mounted) {
      setState(() {
        _isLoggedIn = loggedIn;
        _userName = name;
        _profileImageUrl = profileImg;
        _isChecking = false;
      });
    }

    if (loggedIn) {
      try {
        final res = await AuthApiService.getMe();
        if (res != null && res is Map) {
          final updatedName = (res['fullName'] as String?) ?? name;
          final email =
              (res['email'] as String?) ?? await UserSession.getUserEmail();
          await UserSession.saveUser(
            userId,
            email,
            updatedName,
            profileImageUrl: res['profileImageUrl'] as String?,
          );
          if (mounted) {
            setState(() {
              _userName = updatedName;
              // ยังคงใช้ Backend Streaming URL เพื่อความเสถียร
              if (userId.isNotEmpty) {
                _profileImageUrl = ApiConfig.authProfileImageUrl(userId);
              }
            });
          }
        }
      } catch (_) {}
    }
  }

  Future<void> _openProfile() async {
    await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, _, _) => ProfilePage(
          onProfileUpdated: () {
            _checkInitialLogin();
            _loadModuleVisibility();
          },
          onLogout: _checkInitialLogin,
        ),
        transitionsBuilder: (_, anim, _, child) => SlideTransition(
          position: Tween(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
    );
    _checkInitialLogin();
  }

  void _cycleTheme() {
    final modes = [ThemeMode.system, ThemeMode.light, ThemeMode.dark];
    final labels = ['system', 'light', 'dark'];
    final currentIdx = modes.indexOf(widget.currentThemeMode);
    final nextIdx = (currentIdx + 1) % modes.length;
    widget.onToggleTheme(modes[nextIdx]);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'สลับเป็น ${labels[nextIdx]} mode',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        duration: const Duration(milliseconds: 800),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  IconData get _themeIcon {
    switch (widget.currentThemeMode) {
      case ThemeMode.light:
        return Icons.light_mode_rounded;
      case ThemeMode.dark:
        return Icons.dark_mode_rounded;
      default:
        return Icons.brightness_auto_rounded;
    }
  }

  void _openOnboarding() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OnboardingPage(
          onToggleTheme: widget.onToggleTheme,
          currentThemeMode: widget.currentThemeMode,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    if (_isChecking) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: c.heroGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Mylife',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: c.ink,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: c.accent,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isLoggedIn) {
      return Scaffold(
        body: SafeArea(child: AuthPage(onLoginSuccess: _checkInitialLogin)),
      );
    }

    final labels = ['วันนี้', 'แผนงาน', 'การเงิน', 'สิ่งที่ต้องทำ'];
    final small = context.isSmallScreen;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Column(
        children: [
          // Custom AppBar
          SafeArea(
            bottom: false,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                small ? 14 : 20,
                10,
                small ? 8 : 14,
                8,
              ),
              child: Row(
                children: [
                  // Greeting area
                  Expanded(
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: _openProfile,
                          child: Container(
                            width: small ? 38 : 42,
                            height: small ? 38 : 42,
                            decoration: BoxDecoration(
                              gradient: c.heroGradient,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: c.accent.withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child:
                                  _profileImageUrl != null &&
                                      _profileImageUrl!.isNotEmpty
                                  ? Image.network(
                                      _profileImageUrl!,
                                      width: small ? 38 : 42,
                                      height: small ? 38 : 42,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return Center(
                                              child: Text(
                                                _userName.isNotEmpty
                                                    ? _userName[0].toUpperCase()
                                                    : 'M',
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w900,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            );
                                          },
                                    )
                                  : Center(
                                      child: Text(
                                        _userName.isNotEmpty
                                            ? _userName[0].toUpperCase()
                                            : 'M',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _getGreeting(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: c.ink3,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                _userName,
                                style: TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w900,
                                  color: c.ink,
                                  letterSpacing: -0.4,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Help / Onboarding
                  _buildIconButton(
                    icon: Icons.help_outline_rounded,
                    onTap: _openOnboarding,
                    c: c,
                    small: small,
                  ),
                  // Theme toggle
                  _buildIconButton(
                    icon: _themeIcon,
                    onTap: _cycleTheme,
                    c: c,
                    small: small,
                  ),
                  // Notification bell
                  _buildIconButton(
                    icon: Icons.notifications_outlined,
                    badge: 4,
                    onTap: _showNotificationCenter,
                    c: c,
                    small: small,
                  ),
                  // Profile
                  _buildIconButton(
                    icon: Icons.person_outline_rounded,
                    onTap: _openProfile,
                    c: c,
                    isSelected: false,
                    small: small,
                  ),
                ],
              ),
            ),
          ),
          // Body
          Expanded(
            child: IndexedStack(index: _index, children: _pages),
          ),
          // Offline Banner
          if (!_isOnline)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.orange.shade700,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.wifi_off_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'ออฟไลน์ — ข้อมูลอาจไม่ใช่ล่าสุด',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
          14,
          0,
          14,
          MediaQuery.of(context).padding.bottom > 0 ? 10 : 14,
        ),
        decoration: const BoxDecoration(color: Colors.transparent),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? c.surface.withValues(alpha: 0.96) : c.surface,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: isDark
                  ? c.border.withValues(alpha: 0.8)
                  : c.border.withValues(alpha: 0.7),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.45)
                    : c.ink.withValues(alpha: 0.08),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Row(
              children: [
                // Tab 0: วันนี้
                _buildNavItem(0, labels[0], _icons[0], _iconsOut[0], c, small),
                // Tab 1: แผนงาน
                if (_plannerEnabled) _buildNavItem(1, labels[1], _icons[1], _iconsOut[1], c, small),

                // Center Action Button (+)
                Expanded(
                  child: GestureDetector(
                    onTap: _showUniversalQuickAdd,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: small ? 38 : 42,
                            height: small ? 38 : 42,
                            decoration: BoxDecoration(
                              gradient: c.accentGradient,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: c.accent.withValues(alpha: 0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.add_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'สร้างด่วน',
                            style: TextStyle(
                              fontSize: small ? 9 : 10,
                              fontWeight: FontWeight.w700,
                              color: c.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Tab 2: การเงิน
                if (_financeEnabled) _buildNavItem(2, labels[2], _icons[2], _iconsOut[2], c, small),
                // Tab 3: สิ่งที่ต้องทำ
                if (_todosEnabled) _buildNavItem(3, labels[3], _icons[3], _iconsOut[3], c, small),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    String label,
    IconData iconSelected,
    IconData iconUnselected,
    AppColors c,
    bool small,
  ) {
    final isSelected = _index == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _index = index);
          DataEventService.notifyDataChanged();
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? c.accentSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            border: isSelected
                ? Border.all(color: c.accent.withValues(alpha: 0.2), width: 1)
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? iconSelected : iconUnselected,
                color: isSelected ? c.accent : c.ink3,
                size: small ? 20 : 22,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: small ? 9.5 : 10.5,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                  color: isSelected ? c.accent : c.ink3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showUniversalQuickAdd() {
    final c = context.c;
    showAppBottomSheet(
      context,
      title: 'สร้างรายการด่วน',
      subtitle: 'เลือกประเภทรายการที่ต้องการเพิ่ม',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _quickActionOption(
            icon: Icons.account_balance_wallet_rounded,
            color: c.accent,
            title: 'จดบันทึกรายรับ - รายจ่าย',
            subtitle: 'บันทึกค่าใช้จ่ายหรือเงินเข้ากระเป๋า',
            onTap: () {
              Navigator.pop(context);
              setState(() => _index = 2); // Switch to Finance
            },
          ),
          const SizedBox(height: 10),
          _quickActionOption(
            icon: Icons.check_circle_outline_rounded,
            color: c.good,
            title: 'เพิ่มสิ่งที่ต้องทำ (Todolist)',
            subtitle: 'จดรายการงานประจำวันและเป้าหมาย',
            onTap: () {
              Navigator.pop(context);
              setState(() => _index = 3); // Switch to Todolist
            },
          ),
          const SizedBox(height: 10),
          _quickActionOption(
            icon: Icons.celebration_rounded,
            color: c.violet,
            title: 'เพิ่มกิจกรรม / นัดหมายสำคัญ',
            subtitle: 'สร้างกิจกรรมพร้อมระบบนับถอยหลัง',
            onTap: () {
              Navigator.pop(context);
              setState(() => _index = 1); // Switch to Planner
            },
          ),
          const SizedBox(height: 10),
          _quickActionOption(
            icon: Icons.calendar_month_rounded,
            color: c.amber,
            title: 'เพิ่มวิชาเรียนในตาราง',
            subtitle: 'กำหนดวัน เวลา และห้องเรียน',
            onTap: () {
              Navigator.pop(context);
              setState(() => _index = 1); // Switch to Planner
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _quickActionOption({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final c = context.c;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.surface2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border.withValues(alpha: 0.6)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: c.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: c.ink3)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: c.ink3, size: 20),
          ],
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'สวัสดีตอนเช้า ☀️';
    if (hour < 17) return 'สวัสดีตอนบ่าย 🌤';
    return 'สวัสดีตอนเย็น 🌙';
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onTap,
    required AppColors c,
    int? badge,
    bool isSelected = false,
    bool small = false,
  }) {
    final size = small ? 36.0 : 40.0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        margin: EdgeInsets.symmetric(horizontal: small ? 2 : 3.5),
        decoration: BoxDecoration(
          color: isSelected ? c.accentSoft : c.surface2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? c.accent.withValues(alpha: 0.3)
                : c.border.withValues(alpha: 0.5),
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, color: c.ink2, size: small ? 19 : 21),
            if (badge != null)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: c.coral,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: c.surface, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      '$badge',
                      style: const TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showNotificationCenter() async {
    final userId = await UserSession.getUserId();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final cc = context.c;
        return FutureBuilder<List<SystemNotification>>(
          future: NotificationService.fetchNotificationsFromServer(userId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final notifications = snapshot.data ?? [];

            return Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: cc.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'การแจ้งเตือนสด (Live Server Data)',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: cc.ink,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: cc.accentSoft,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${notifications.length} รายการ',
                          style: TextStyle(
                            fontSize: 11,
                            color: cc.accent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (var item in notifications)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cc.surface2,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: item.color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(item.icon, color: item.color, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: cc.ink,
                                  ),
                                ),
                                Text(
                                  item.message,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: cc.ink3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  AppColors? get c {
    try {
      return Theme.of(context).extension<AppColors>();
    } catch (_) {
      return null;
    }
  }
}
