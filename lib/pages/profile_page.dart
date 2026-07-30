import 'package:flutter/material.dart';
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

class _ProfilePageState extends State<ProfilePage> {
  final _nameController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _email = '';
  String _userId = '';
  bool _isLoadingProfile = true;
  bool _isSavingProfile = false;
  bool _isChangingPassword = false;

  // Integrations state
  bool _isLoadingIntegrations = true;
  bool _googleConnected = false;
  bool _lineConnected = false;
  String? _lineUserId;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    _userId = await UserSession.getUserId();
    _email = await UserSession.getUserEmail();
    _nameController.text = await UserSession.getUserName();

    if (mounted) {
      setState(() {
        _isLoadingProfile = false;
      });
    }

    await Future.wait([
      _fetchUserProfile(),
      _fetchIntegrations(),
    ]);
  }

  Future<void> _fetchUserProfile() async {
    try {
      final res = await AuthApiService.getMe();
      if (res != null && res is Map) {
        if (res['fullName'] != null) {
          _nameController.text = res['fullName'];
          await UserSession.saveUser(
            _userId,
            res['email'] ?? _email,
            res['fullName'],
          );
        }
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

    if (mounted) {
      setState(() => _isLoadingIntegrations = false);
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
      _showMessage('เกิดข้อผิดพลาด: ${e.toString().replaceAll('Exception: ', '')}');
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
      _showMessage('เกิดข้อผิดพลาด: ${e.toString().replaceAll('Exception: ', '')}');
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
      } catch (e) {
        _showMessage('ไม่สามารถเชื่อมต่อ Google Calendar ได้');
      }
    } else {
      try {
        await GoogleCalendarApiService.deleteConnection(_userId);
        _showMessage('ยกเลิกการเชื่อมต่อ Google Calendar แล้ว');
        _fetchIntegrations();
      } catch (e) {
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
              onPressed: () => Navigator.pop(context, lineIdController.text.trim()),
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
        } catch (e) {
          _showMessage('ไม่สามารถผูกบัญชี LINE ได้');
        }
      }
    } else {
      try {
        await LineApiService.disconnect(_userId);
        _showMessage('ยกเลิกการเชื่อมต่อ LINE เรียบร้อยแล้ว');
        _fetchIntegrations();
      } catch (e) {
        _showMessage('ไม่สามารถยกเลิกการเชื่อมต่อได้');
      }
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
            child: const Text('ออกจากระบบ', style: TextStyle(color: Colors.white)),
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>() ?? AppColors.light;

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        title: const Text('โปรไฟล์และการตั้งค่า', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
      ),
      body: _isLoadingProfile
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // User Header Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: colors.heroGradient,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: colors.accent.withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          child: const Icon(Icons.person, size: 40, color: Colors.white),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _nameController.text.isNotEmpty ? _nameController.text : 'ผู้ใช้งาน Mylife',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _email,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 1. Profile Editing Card
                  _buildCard(
                    colors: colors,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader('แก้ไขข้อมูลส่วนตัว', Icons.badge_outlined, colors),
                        const SizedBox(height: 16),
                        TextField(
                          controller: TextEditingController(text: _email),
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'อีเมล (อ่านอย่างเดียว)',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'ชื่อ-นามสกุล',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isSavingProfile ? null : _saveProfile,
                            icon: _isSavingProfile
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.save_outlined),
                            label: const Text('บันทึกข้อมูลส่วนตัว'),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 2. Change Password Card
                  _buildCard(
                    colors: colors,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader('เปลี่ยนรหัสผ่าน', Icons.lock_outline, colors),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _currentPasswordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'รหัสผ่านปัจจุบัน',
                            prefixIcon: Icon(Icons.key_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _newPasswordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'รหัสผ่านใหม่ (อย่างน้อย 6 ตัวอักษร)',
                            prefixIcon: Icon(Icons.lock_reset_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _confirmPasswordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'ยืนยันรหัสผ่านใหม่',
                            prefixIcon: Icon(Icons.check_circle_outline),
                          ),
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
                                : const Icon(Icons.password_outlined),
                            label: const Text('เปลี่ยนรหัสผ่าน'),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 3. Integrations Card
                  _buildCard(
                    colors: colors,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader('การเชื่อมต่อบริการภายนอก', Icons.extension_outlined, colors),
                        const SizedBox(height: 16),
                        if (_isLoadingIntegrations)
                          const Center(child: CircularProgressIndicator())
                        else ...[
                          Card(
                            elevation: 0,
                            color: colors.surface2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: colors.border),
                            ),
                            child: SwitchListTile(
                              secondary: const Icon(Icons.calendar_month, color: Colors.redAccent),
                              title: const Text('Google Calendar'),
                              subtitle: Text(
                                _googleConnected ? 'เชื่อมต่อแล้ว (ซิงก์กิจกรรมอัตโนมัติ)' : 'ยังไม่ได้เชื่อมต่อ',
                                style: TextStyle(color: colors.ink2, fontSize: 12),
                              ),
                              value: _googleConnected,
                              onChanged: _toggleGoogleCalendar,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Card(
                            elevation: 0,
                            color: colors.surface2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: colors.border),
                            ),
                            child: SwitchListTile(
                              secondary: const Icon(Icons.chat_bubble_outline, color: Colors.green),
                              title: const Text('LINE Notifications'),
                              subtitle: Text(
                                _lineConnected
                                    ? 'เชื่อมต่อแล้ว (${_lineUserId ?? ''})'
                                    : 'ยังไม่ได้เชื่อมต่อ (รับการแจ้งเตือนทาง LINE)',
                                style: TextStyle(color: colors.ink2, fontSize: 12),
                              ),
                              value: _lineConnected,
                              onChanged: _toggleLine,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 4. Health Data Card Link
                  _buildCard(
                    colors: colors,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.favorite_rounded, color: colors.coral, size: 28),
                      title: const Text('ข้อมูลสุขภาพและการเต้นของหัวใจ', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('ดูสถิติก้าวเดินและอัตราการเต้นหัวใจ', style: TextStyle(color: colors.ink2, fontSize: 12)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const Scaffold(body: SafeArea(child: HealthPage()))),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 5. Logout Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.coral,
                        side: BorderSide(color: colors.coral),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _handleLogout,
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('ออกจากระบบ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildCard({required AppColors colors, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, AppColors colors) {
    return Row(
      children: [
        Icon(icon, size: 22, color: colors.accent),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: colors.ink,
          ),
        ),
      ],
    );
  }
}
