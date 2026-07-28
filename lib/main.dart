import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'theme/app_theme.dart';
import 'widgets/common.dart';
import 'pages/overview_page.dart';
import 'pages/finance_page.dart';
import 'pages/schedule_page.dart';
import 'pages/activity_page.dart';
import 'pages/todolist_page.dart';
import 'pages/tasks_page.dart';
import 'pages/health_page.dart';
import 'pages/auth_page.dart';
import 'pages/onboarding_page.dart';
import 'services/user_session.dart';
import 'services/notification_service.dart';
import 'services/connectivity_service.dart';
import 'services/api_client.dart';
import 'services/data_event_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
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
        builder: (context, child) => ResponsiveContainer(child: child ?? const SizedBox()),
        home: const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return MaterialApp(
      title: 'Mylife',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _themeMode,
      builder: (context, child) => ResponsiveContainer(child: child ?? const SizedBox()),
      home: _isFirstRun
          ? OnboardingPage(onToggleTheme: _setThemeMode, currentThemeMode: _themeMode)
          : HomeShell(onToggleTheme: _setThemeMode, currentThemeMode: _themeMode),
    );
  }
}

class HomeShell extends StatefulWidget {
  final void Function(ThemeMode) onToggleTheme;
  final ThemeMode currentThemeMode;
  const HomeShell({super.key, required this.onToggleTheme, required this.currentThemeMode});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  bool _isChecking = true;
  bool _isLoggedIn = false;
  String _userName = 'โปรไฟล์';
  bool _isOnline = true;
  StreamSubscription<bool>? _connectivitySubscription;

  static const _pages = <Widget>[
    OverviewPage(),
    FinancePage(),
    SchedulePage(),
    TodolistPage(),
    ActivityPage(),
    TasksPage(),
  ];

  static const _icons = <IconData>[
    Icons.dashboard_rounded,
    Icons.account_balance_wallet_rounded,
    Icons.calendar_month_rounded,
    Icons.check_circle_rounded,
    Icons.celebration_rounded,
    Icons.assignment_rounded,
  ];

  static const _iconsOut = <IconData>[
    Icons.dashboard_outlined,
    Icons.account_balance_wallet_outlined,
    Icons.calendar_month_outlined,
    Icons.check_circle_outline,
    Icons.celebration_outlined,
    Icons.assignment_outlined,
  ];

  @override
  void initState() {
    super.initState();
    _isOnline = ConnectivityService.isOnline;
    ApiClient.setOffline(!_isOnline);
    _connectivitySubscription = ConnectivityService.isOnlineStream.listen((isOnline) {
      if (mounted) {
        setState(() {
          _isOnline = isOnline;
          ApiClient.setOffline(!isOnline);
        });
        if (isOnline) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('กลับมาออนไลน์แล้ว — ดึงหน้าจอเพื่ออัพเดทข้อมูล', style: TextStyle(fontWeight: FontWeight.w600)),
              backgroundColor: Color(0xFF4CAF50),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    });
    _checkInitialLogin();
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
    if (mounted) {
      setState(() {
        _isLoggedIn = loggedIn;
        _userName = name;
        _isChecking = false;
      });
    }
  }

  Future<void> _openProfile() async {
    await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, _, _) => const Scaffold(body: SafeArea(child: HealthPage())),
        transitionsBuilder: (_, anim, _, child) => SlideTransition(
          position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
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
        content: Text('สลับเป็น ${labels[nextIdx]} mode', style: const TextStyle(fontWeight: FontWeight.w700)),
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
                child: const Icon(Icons.auto_awesome, color: Colors.white, size: 32),
              ),
              const SizedBox(height: 20),
              Text('Mylife', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: c.ink, letterSpacing: -1)),
              const SizedBox(height: 12),
              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(strokeWidth: 3, color: c.accent),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isLoggedIn) {
      return Scaffold(
        body: SafeArea(
          child: AuthPage(onLoginSuccess: _checkInitialLogin),
        ),
      );
    }

    final labels = ['ภาพรวม', 'การเงิน', 'ตารางเรียน', 'Todolist', 'กิจกรรม', 'งาน'];
    final small = context.isSmallScreen;

    return Scaffold(
      body: Column(
        children: [
          // Custom AppBar
          SafeArea(
            bottom: false,
            child: Container(
              padding: EdgeInsets.fromLTRB(small ? 12 : 20, 8, small ? 6 : 12, 0),
              child: Row(
                children: [
                  // Greeting area
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: small ? 34 : 38,
                              height: small ? 34 : 38,
                              decoration: BoxDecoration(
                                gradient: c.accentGradient,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: c.accent.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _getGreeting(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.ink3),
                                  ),
                                  Text(
                                    _userName,
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.ink, letterSpacing: -0.3),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
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
                    Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
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
        decoration: BoxDecoration(
          color: c.surface,
          border: Border(top: BorderSide(color: c.border.withValues(alpha: 0.5), width: 0.5)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: List.generate(_icons.length, (i) {
                final isSelected = _index == i;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _index = i);
                      DataEventService.notifyDataChanged();
                    },
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? c.accentSoft : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isSelected ? _icons[i] : _iconsOut[i],
                            color: isSelected ? c.accent : c.ink3,
                            size: small ? 21 : 24,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            labels[i],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: small ? 9.5 : 10.5,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                              color: isSelected ? c.accent : c.ink3,
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
    final size = small ? 34.0 : 40.0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        margin: EdgeInsets.symmetric(horizontal: small ? 1.5 : 3),
        decoration: BoxDecoration(
          color: isSelected ? c.accentSoft : c.surface2,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, color: c.ink2, size: small ? 19 : 22),
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
                      style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.white),
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
                      Text('การแจ้งเตือนสด (Live Server Data)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: cc.ink)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: cc.accentSoft, borderRadius: BorderRadius.circular(6)),
                        child: Text('${notifications.length} รายการ', style: TextStyle(fontSize: 11, color: cc.accent, fontWeight: FontWeight.bold)),
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
                                Text(item.title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: cc.ink)),
                                Text(item.message, style: TextStyle(fontSize: 12, color: cc.ink3)),
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


