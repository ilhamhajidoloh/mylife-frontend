import 'package:flutter/material.dart';
import '../services/api_services.dart';
import '../services/user_session.dart';
import '../theme/app_theme.dart';

class ProfileSettingsDialog extends StatefulWidget {
  final VoidCallback? onProfileUpdated;

  const ProfileSettingsDialog({super.key, this.onProfileUpdated});

  static Future<void> show(BuildContext context, {VoidCallback? onProfileUpdated}) {
    return showDialog(
      context: context,
      builder: (context) => ProfileSettingsDialog(onProfileUpdated: onProfileUpdated),
    );
  }

  @override
  State<ProfileSettingsDialog> createState() => _ProfileSettingsDialogState();
}

class _ProfileSettingsDialogState extends State<ProfileSettingsDialog> {
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

    setState(() {
      _isLoadingProfile = false;
    });

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

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>() ?? AppColors.light;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 680),
        color: colors.surface,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                gradient: colors.accentGradient,
              ),
              child: Row(
                children: [
                  const Icon(Icons.manage_accounts, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'ตั้งค่าโปรไฟล์ & การเชื่อมต่อ',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content Body
            Expanded(
              child: _isLoadingProfile
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Profile Section
                          _buildSectionHeader('ข้อมูลส่วนตัว', Icons.person_outline, colors),
                          const SizedBox(height: 12),
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
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton.icon(
                              onPressed: _isSavingProfile ? null : _saveProfile,
                              icon: _isSavingProfile
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.save_outlined),
                              label: const Text('บันทึกข้อมูลส่วนตัว'),
                            ),
                          ),

                          const Divider(height: 32),

                          // 2. Password Section
                          _buildSectionHeader('เปลี่ยนรหัสผ่าน', Icons.lock_outline, colors),
                          const SizedBox(height: 12),
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
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: OutlinedButton.icon(
                              onPressed: _isChangingPassword ? null : _changePassword,
                              icon: _isChangingPassword
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.password),
                              label: const Text('เปลี่ยนรหัสผ่าน'),
                            ),
                          ),

                          const Divider(height: 32),

                          // 3. Integrations Section
                          _buildSectionHeader('การเชื่อมต่อบริการภายนอก', Icons.extension_outlined, colors),
                          const SizedBox(height: 12),

                          if (_isLoadingIntegrations)
                            const Center(child: CircularProgressIndicator())
                          else ...[
                            // Google Calendar
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

                            // LINE Notifications
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, AppColors colors) {
    return Row(
      children: [
        Icon(icon, size: 20, color: colors.accent),
        const SizedBox(width: 8),
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
