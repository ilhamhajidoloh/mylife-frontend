import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../config/api_config.dart';
import '../services/api_services.dart';
import '../services/user_session.dart';
import '../theme/app_theme.dart';
import 'health_page.dart';

class ProfilePage extends StatefulWidget {
  final VoidCallback? onProfileUpdated;
  final VoidCallback? onLogout;

  const ProfilePage({super.key, this.onProfileUpdated, this.onLogout});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _email = '';
  String _userId = '';
  String? _profileImageUrl;
  bool _isLoadingProfile = true;
  bool _isSavingProfile = false;
  bool _isChangingPassword = false;
  bool _showCurrentPw = false;
  bool _showNewPw = false;
  bool _showConfirmPw = false;

  // Upload
  bool _isUploadingImage = false;

  // Integrations state
  bool _isLoadingIntegrations = true;
  bool _googleConnected = false;
  bool _lineConnected = false;
  String? _lineUserId;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _loadInitialData();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _nameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    _userId = await UserSession.getUserId();
    _email = await UserSession.getUserEmail();
    _nameController.text = await UserSession.getUserName();

    // ใช้ Backend Streaming URL เสมอ
    _profileImageUrl = _userId.isNotEmpty
        ? ApiConfig.authProfileImageUrl(_userId)
        : null;

    if (mounted) {
      setState(() => _isLoadingProfile = false);
      _animCtrl.forward();
    }

    await Future.wait([_fetchUserProfile(), _fetchIntegrations()]);
  }

  Future<void> _fetchUserProfile() async {
    try {
      final res = await AuthApiService.getMe();
      if (res != null && res is Map) {
        if (res['fullName'] != null) _nameController.text = res['fullName'];
        await UserSession.saveUser(
          _userId,
          res['email'] ?? _email,
          res['fullName'] ?? _nameController.text,
          profileImageUrl: res['profileImageUrl'] as String?,
        );
        if (mounted) setState(() {});
      }
    } catch (_) {}
  }

  Future<void> _fetchIntegrations() async {
    if (!mounted) return;
    setState(() => _isLoadingIntegrations = true);
    try {
      final gRes = await GoogleCalendarApiService.getConnection(_userId);
      _googleConnected = (gRes != null && gRes is Map && gRes['id'] != null);
    } catch (_) {
      _googleConnected = false;
    }
    try {
      final lRes = await LineApiService.getConnection(_userId);
      if (lRes != null && lRes is Map) {
        _lineConnected = lRes['connected'] == true;
        _lineUserId = lRes['lineUserId'];
      }
    } catch (_) {
      _lineConnected = false;
    }
    if (mounted) setState(() => _isLoadingIntegrations = false);
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 800,
      );
      if (picked == null || !mounted) return;

      setState(() => _isUploadingImage = true);

      final file = File(picked.path);
      final res = await AuthApiService.uploadProfileImage(_userId, file);

      if (res != null && mounted) {
        // Force reload with timestamp to bust cache
        final ts = DateTime.now().millisecondsSinceEpoch;
        setState(() {
          _profileImageUrl = '${ApiConfig.authProfileImageUrl(_userId)}?t=$ts';
          _isUploadingImage = false;
        });
        _showMessage('อัปโหลดรูปโปรไฟล์สำเร็จ');
        widget.onProfileUpdated?.call();
      } else {
        if (mounted) setState(() => _isUploadingImage = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingImage = false);
        _showMessage(
          'เกิดข้อผิดพลาด: ${e.toString().replaceAll('Exception: ', '')}',
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showMessage('กรุณาระบุชื่อ-นามสกุล');
      return;
    }
    setState(() => _isSavingProfile = true);
    try {
      final res = await AuthApiService.updateProfile(name);
      if (res != null) {
        await UserSession.saveUser(_userId, _email, name);
        _showMessage('บันทึกข้อมูลส่วนตัวเรียบร้อยแล้ว');
        widget.onProfileUpdated?.call();
      }
    } catch (e) {
      _showMessage(
        'เกิดข้อผิดพลาด: ${e.toString().replaceAll('Exception: ', '')}',
      );
    } finally {
      if (mounted) setState(() => _isSavingProfile = false);
    }
  }

  Future<void> _changePassword() async {
    final currentPw = _currentPasswordController.text.trim();
    final newPw = _newPasswordController.text.trim();
    final confirmPw = _confirmPasswordController.text.trim();

    if (currentPw.isEmpty || newPw.isEmpty) {
      _showMessage('กรุณากรอกรหัสผ่านปัจจุบันและรหัสผ่านใหม่');
      return;
    }
    if (newPw.length < 6) {
      _showMessage('รหัสผ่านใหม่ต้องมีอย่างน้อย 6 ตัวอักษร');
      return;
    }
    if (newPw != confirmPw) {
      _showMessage('รหัสผ่านใหม่ยืนยันไม่ตรงกัน');
      return;
    }
    setState(() => _isChangingPassword = true);
    try {
      final res = await AuthApiService.changePassword(currentPw, newPw);
      if (res != null) {
        _showMessage('เปลี่ยนรหัสผ่านสำเร็จ');
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      }
    } catch (e) {
      _showMessage(
        'เกิดข้อผิดพลาด: ${e.toString().replaceAll('Exception: ', '')}',
      );
    } finally {
      if (mounted) setState(() => _isChangingPassword = false);
    }
  }

  Future<void> _toggleGoogleCalendar(bool value) async {
    if (value) {
      try {
        final now = DateTime.now().add(const Duration(days: 30));
        await GoogleCalendarApiService.upsertConnection(
          _userId,
          'sample_access_token',
          'sample_refresh_token',
          now,
        );
        _showMessage('เชื่อมต่อ Google Calendar เรียบร้อยแล้ว');
        _fetchIntegrations();
      } catch (_) {
        _showMessage('ไม่สามารถเชื่อมต่อ Google Calendar ได้');
      }
    } else {
      try {
        await GoogleCalendarApiService.deleteConnection(_userId);
        _showMessage('ยกเลิกการเชื่อมต่อ Google Calendar แล้ว');
        _fetchIntegrations();
      } catch (_) {
        _showMessage('ไม่สามารถยกเลิกการเชื่อมต่อได้');
      }
    }
  }

  Future<void> _toggleLine(bool value) async {
    if (value) {
      final lineIdController = TextEditingController(text: _lineUserId ?? '');
      final lineId = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('ผูกบัญชี LINE Notify'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('กรอก LINE User ID สำหรับรับการแจ้งเตือน:'),
              const SizedBox(height: 12),
              TextField(
                controller: lineIdController,
                decoration: const InputDecoration(
                  labelText: 'LINE User ID',
                  hintText: 'U1234567890abcdef...',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(context, lineIdController.text.trim()),
              child: const Text('ตกลง'),
            ),
          ],
        ),
      );
      if (lineId != null && lineId.isNotEmpty) {
        try {
          await LineApiService.connect(_userId, lineId);
          _showMessage('ผูกบัญชี LINE เรียบร้อยแล้ว');
          _fetchIntegrations();
        } catch (_) {
          _showMessage('ไม่สามารถผูกบัญชี LINE ได้');
        }
      }
    } else {
      try {
        await LineApiService.disconnect(_userId);
        _showMessage('ยกเลิกการเชื่อมต่อ LINE เรียบร้อยแล้ว');
        _fetchIntegrations();
      } catch (_) {
        _showMessage('ไม่สามารถยกเลิกการเชื่อมต่อได้');
      }
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('ออกจากระบบ'),
        content: const Text('คุณต้องการออกจากระบบใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'ออกจากระบบ',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await UserSession.clearUser();
      if (mounted) {
        widget.onLogout?.call();
        Navigator.pop(context);
      }
    }
  }

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ─── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>() ?? AppColors.light;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'โปรไฟล์และการตั้งค่า',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: c.ink,
          ),
        ),
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              color: c.surface2,
              shape: BoxShape.circle,
              border: Border.all(color: c.border),
            ),
            child: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 16,
                color: c.ink,
              ),
              onPressed: () => Navigator.pop(context),
              padding: EdgeInsets.zero,
            ),
          ),
        ),
      ),
      body: _isLoadingProfile
          ? const Center(child: CircularProgressIndicator())
          : FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
                child: Column(
                  children: [
                    // ── 1. Hero Profile Card ──────────────────────────────
                    _buildHeroProfileCard(c),

                    const SizedBox(height: 18),

                    // ── 2. Profile Info Card ───────────────────────────────
                    _buildSectionCard(
                      c,
                      icon: Icons.badge_outlined,
                      title: 'ข้อมูลส่วนตัว',
                      child: _buildProfileForm(c),
                    ),

                    const SizedBox(height: 16),

                    // ── 3. Change Password Card ────────────────────────────
                    _buildSectionCard(
                      c,
                      icon: Icons.lock_outline_rounded,
                      title: 'เปลี่ยนรหัสผ่าน',
                      child: _buildPasswordForm(c),
                    ),

                    const SizedBox(height: 16),

                    // ── 4. Integrations Card ───────────────────────────────
                    _buildSectionCard(
                      c,
                      icon: Icons.hub_outlined,
                      title: 'การเชื่อมต่อบริการภายนอก',
                      child: _buildIntegrations(c),
                    ),

                    const SizedBox(height: 16),

                    // ── 5. Quick Links ─────────────────────────────────────
                    _buildQuickLinks(c),

                    const SizedBox(height: 24),

                    // ── 6. Logout ──────────────────────────────────────────
                    _buildLogoutButton(c),
                  ],
                ),
              ),
            ),
    );
  }

  // ─── Hero Profile Card ──────────────────────────────────────────────────────
  Widget _buildHeroProfileCard(AppColors c) {
    final initial = _nameController.text.isNotEmpty
        ? _nameController.text[0].toUpperCase()
        : 'U';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        gradient: c.heroGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: c.accent.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avatar with edit button
          Stack(
            alignment: Alignment.center,
            children: [
              // Outer glow
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.18),
                ),
              ),
              // Main Avatar
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: _isUploadingImage
                      ? Container(
                          color: Colors.white.withValues(alpha: 0.2),
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          ),
                        )
                      : Image.network(
                          _profileImageUrl ??
                              ApiConfig.authProfileImageUrl(_userId),
                          width: 92,
                          height: 92,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, _) => Container(
                            color: Colors.white.withValues(alpha: 0.2),
                            alignment: Alignment.center,
                            child: Text(
                              initial,
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          loadingBuilder: (_, child, progress) =>
                              progress == null
                              ? child
                              : Container(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  child: const Center(
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                ),
              ),
              // Camera button
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _isUploadingImage ? null : _pickAndUploadImage,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.camera_alt_rounded,
                      size: 17,
                      color: c.accent,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Full Name
          Text(
            _nameController.text.isNotEmpty
                ? _nameController.text
                : 'ผู้ใช้งาน Mylife',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
            ),
          ),

          const SizedBox(height: 4),

          // Email
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.email_outlined,
                size: 14,
                color: Colors.white.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  _email,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Oracle Cloud Storage Pill Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_done_rounded, size: 14, color: Colors.white),
                SizedBox(width: 6),
                Text(
                  'Oracle Cloud Storage',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Section Card ────────────────────────────────────────────────────────────
  Widget _buildSectionCard(
    AppColors c, {
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: c.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: c.accent),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: c.ink,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: c.border),
          // Content
          Padding(padding: const EdgeInsets.all(18), child: child),
        ],
      ),
    );
  }

  // ─── Profile Form ─────────────────────────────────────────────────────────
  Widget _buildProfileForm(AppColors c) {
    return Column(
      children: [
        _readonlyField(
          label: 'อีเมล',
          value: _email,
          icon: Icons.email_outlined,
          c: c,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: 'ชื่อ-นามสกุล',
            prefixIcon: Icon(Icons.person_outline, color: c.accent),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: c.surface2,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _isSavingProfile ? null : _saveProfile,
            icon: _isSavingProfile
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_rounded, size: 18),
            label: const Text(
              'บันทึกข้อมูล',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Password Form ────────────────────────────────────────────────────────
  Widget _buildPasswordForm(AppColors c) {
    return Column(
      children: [
        _passwordField(
          label: 'รหัสผ่านปัจจุบัน',
          controller: _currentPasswordController,
          icon: Icons.key_rounded,
          show: _showCurrentPw,
          onToggle: () => setState(() => _showCurrentPw = !_showCurrentPw),
          c: c,
        ),
        const SizedBox(height: 12),
        _passwordField(
          label: 'รหัสผ่านใหม่ (อย่างน้อย 6 ตัว)',
          controller: _newPasswordController,
          icon: Icons.lock_reset_rounded,
          show: _showNewPw,
          onToggle: () => setState(() => _showNewPw = !_showNewPw),
          c: c,
        ),
        const SizedBox(height: 12),
        _passwordField(
          label: 'ยืนยันรหัสผ่านใหม่',
          controller: _confirmPasswordController,
          icon: Icons.check_circle_outline_rounded,
          show: _showConfirmPw,
          onToggle: () => setState(() => _showConfirmPw = !_showConfirmPw),
          c: c,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isChangingPassword ? null : _changePassword,
            icon: _isChangingPassword
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.password_rounded, size: 18),
            label: const Text(
              'เปลี่ยนรหัสผ่าน',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Integrations ─────────────────────────────────────────────────────────
  Widget _buildIntegrations(AppColors c) {
    if (_isLoadingIntegrations) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(8),
          child: CircularProgressIndicator(),
        ),
      );
    }
    return Column(
      children: [
        _integrationTile(
          c: c,
          icon: Icons.calendar_month_rounded,
          iconColor: Colors.redAccent,
          title: 'Google Calendar',
          subtitle: _googleConnected
              ? 'เชื่อมต่อแล้ว — ซิงก์กิจกรรมอัตโนมัติ'
              : 'แตะเพื่อเชื่อมต่อ',
          value: _googleConnected,
          onChanged: _toggleGoogleCalendar,
        ),
        const SizedBox(height: 10),
        _integrationTile(
          c: c,
          icon: Icons.chat_bubble_rounded,
          iconColor: const Color(0xFF00C300),
          title: 'LINE Notifications',
          subtitle: _lineConnected
              ? 'เชื่อมต่อแล้ว — ${_lineUserId ?? ''}'
              : 'รับการแจ้งเตือนผ่าน LINE',
          value: _lineConnected,
          onChanged: _toggleLine,
        ),
      ],
    );
  }

  // ─── Quick Links ──────────────────────────────────────────────────────────
  Widget _buildQuickLinks(AppColors c) {
    return Column(
      children: [
        _quickLinkTile(
          c: c,
          icon: Icons.favorite_rounded,
          iconColor: c.coral,
          title: 'ข้อมูลสุขภาพ',
          subtitle: 'สถิติก้าวเดินและอัตราการเต้นหัวใจ',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const Scaffold(body: SafeArea(child: HealthPage())),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Logout Button ────────────────────────────────────────────────────────
  Widget _buildLogoutButton(AppColors c) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.coral,
          side: BorderSide(color: c.coral.withValues(alpha: 0.6)),
          backgroundColor: c.coral.withValues(alpha: 0.05),
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: _handleLogout,
        icon: const Icon(Icons.logout_rounded),
        label: const Text(
          'ออกจากระบบ',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }

  // ─── Helper Widgets ───────────────────────────────────────────────────────
  Widget _readonlyField({
    required String label,
    required String value,
    required IconData icon,
    required AppColors c,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: c.ink2),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: c.ink2)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    color: c.ink,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.lock_rounded, size: 15, color: c.ink2),
        ],
      ),
    );
  }

  Widget _passwordField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required bool show,
    required VoidCallback onToggle,
    required AppColors c,
  }) {
    return TextField(
      controller: controller,
      obscureText: !show,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: c.accent),
        suffixIcon: IconButton(
          icon: Icon(
            show ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            size: 20,
          ),
          onPressed: onToggle,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: c.surface2,
      ),
    );
  }

  Widget _integrationTile({
    required AppColors c,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required void Function(bool) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: value ? iconColor.withValues(alpha: 0.35) : c.border,
        ),
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        secondary: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: iconColor),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: c.ink,
          ),
        ),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: c.ink2)),
        value: value,
        onChanged: onChanged,
        activeThumbColor: iconColor,
      ),
    );
  }

  Widget _quickLinkTile({
    required AppColors c,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: c.ink,
          ),
        ),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: c.ink2)),
        trailing: Icon(Icons.chevron_right_rounded, color: c.ink2, size: 22),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
