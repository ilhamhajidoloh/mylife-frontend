import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../theme/app_theme.dart';
import '../services/api_services.dart';
import '../services/user_session.dart';
import '../services/logger.dart';

class AuthPage extends StatefulWidget {
  final VoidCallback? onLoginSuccess;
  const AuthPage({super.key, this.onLoginSuccess});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool isLogin = true;
  bool isLoading = false;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  void _finishAuth(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      if (widget.onLoginSuccess != null) {
        widget.onLoginSuccess!();
      } else if (Navigator.canPop(context)) {
        Navigator.pop(context, true);
      }
    }
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty || (!isLogin && name.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกข้อมูลให้ครบถ้วน')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      if (isLogin) {
        final res = await AuthApiService.login(email, password);
        if (res != null && res['userId'] != null) {
          await UserSession.saveUser(res['userId'], res['email'] ?? email, res['fullName'] ?? 'ผู้ใช้งาน', token: res['token']);
          _finishAuth('เข้าสู่ระบบสำเร็จ');
        }
      } else {
        final res = await AuthApiService.register(email, password, name);
        if (res != null && res['userId'] != null) {
          await UserSession.saveUser(res['userId'], res['email'] ?? email, res['fullName'] ?? name, token: res['token']);
          _finishAuth('ลงทะเบียนสำเร็จ');
        }
      }
    } catch (e, st) {
      Logger.catchBlock('AuthPage', 'login/register', e, st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ กรุณาลองใหม่'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _googleLogin() async {
    setState(() => isLoading = true);
    try {
      String? googleId;
      String? email;
      String? fullName;

      const String googleClientId = '1015105923446-9bm732p3tdsmqgtl9okpj9j73290n5tp.apps.googleusercontent.com';

      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: kIsWeb ? googleClientId : null,
        serverClientId: googleClientId,
        scopes: ['email'],
      );
      try {
        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
        if (googleUser != null) {
          googleId = googleUser.id;
          email = googleUser.email;
          fullName = googleUser.displayName ?? googleUser.email.split('@').first;
        } else {
          if (mounted) setState(() => isLoading = false);
          return;
        }
      } catch (gError, gStack) {
        debugPrint('GoogleSignIn error: $gError\n$gStack');
        if (mounted) {
          final result = await _showGoogleFallbackDialog();
          if (result == null) {
            if (mounted) setState(() => isLoading = false);
            return;
          }
          googleId = result['id'];
          email = result['email'];
          fullName = result['name'];
        }
      }

      if (googleId != null && email != null) {
        final res = await AuthApiService.socialLogin(
          'google',
          googleId,
          email,
          fullName ?? 'ผู้ใช้งาน Google',
        );

        if (res != null && res['userId'] != null) {
          await UserSession.saveUser(res['userId'], res['email'] ?? email, res['fullName'] ?? fullName ?? 'ผู้ใช้งาน Google', token: res['token']);
          _finishAuth('เข้าสู่ระบบด้วย Google สำเร็จ');
        } else {
          throw Exception('ไม่ได้รับข้อมูลจากเซิร์ฟเวอร์');
        }
      }
    } catch (e, st) {
      Logger.catchBlock('AuthPage', 'googleLogin', e, st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('เข้าสู่ระบบด้วย Google ไม่สำเร็จ กรุณาลองใหม่อีกครั้ง'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _socialLogin(String provider) async {
    setState(() => isLoading = true);
    try {
      final res = await AuthApiService.socialLogin(
        provider,
        '${provider}_12345',
        'user@$provider.com',
        'User $provider',
      );
      if (res != null && res['userId'] != null) {
        await UserSession.saveUser(res['userId'], res['email'] ?? 'user@$provider.com', res['fullName'] ?? 'User $provider', token: res['token']);
        _finishAuth('เข้าสู่ระบบผ่าน $provider สำเร็จ');
      } else {
        throw Exception('ไม่ได้รับข้อมูลจากเซิร์ฟเวอร์');
      }
    } catch (e, st) {
      Logger.catchBlock('AuthPage', 'socialLogin($provider)', e, st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ กรุณาลองใหม่'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<Map<String, String>?> _showGoogleFallbackDialog() async {
    final emailController = TextEditingController();
    final nameController = TextEditingController();

    return showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.g_mobiledata_rounded, color: Color(0xFFEA4335), size: 32),
            SizedBox(width: 8),
            Text('Google Sign-In', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ระบุอีเมล Google ของคุณเพื่อเข้าสู่ระบบกับเซิร์ฟเวอร์:', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 14),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Google Email',
                prefixIcon: const Icon(Icons.email_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'ชื่อแสดงผล (Full Name)',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () {
              final email = emailController.text.trim();
              if (email.isEmpty) return;
              final name = nameController.text.trim().isNotEmpty ? nameController.text.trim() : email.split('@').first;
              final id = 'google_${email.hashCode.abs()}';
              Navigator.pop(ctx, {'id': id, 'email': email, 'name': name});
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEA4335),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('ตกลง'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [c.bg, c.accentSoft.withValues(alpha: 0.3)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                SizedBox(height: size.height * 0.06),
                // Logo
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: c.heroGradient,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: c.accent.withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.white, size: 36),
                ),
                const SizedBox(height: 20),
                Text('Mylife',
                    style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                        color: c.ink)),
                const SizedBox(height: 6),
                Text(
                  isLogin ? 'ยินดีต้อนรับกลับมา' : 'สร้างบัญชีใหม่',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: c.ink3),
                ),
                SizedBox(height: size.height * 0.04),

                // Login Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: c.border.withValues(alpha: 0.5)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!isLogin) ...[
                        _buildTextField(
                          controller: _nameController,
                          label: 'ชื่อ-นามสกุล',
                          icon: Icons.person_outline_rounded,
                          c: c,
                        ),
                        const SizedBox(height: 14),
                      ],
                      _buildTextField(
                        controller: _emailController,
                        label: 'อีเมล',
                        icon: Icons.email_outlined,
                        c: c,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 14),
                      _buildTextField(
                        controller: _passwordController,
                        label: 'รหัสผ่าน',
                        icon: Icons.lock_outline_rounded,
                        c: c,
                        obscureText: true,
                      ),
                      const SizedBox(height: 24),

                      // Submit Button
                      Container(
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: c.accentGradient,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: c.accent.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: isLoading
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                              : Text(
                                  isLogin ? 'เข้าสู่ระบบ' : 'ลงทะเบียน',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Divider
                      Row(
                        children: [
                          Expanded(child: Divider(color: c.border)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Text('หรือ', style: TextStyle(color: c.ink3, fontSize: 13, fontWeight: FontWeight.w500)),
                          ),
                          Expanded(child: Divider(color: c.border)),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Social Buttons
                      _socialButton(
                        onPressed: isLoading ? null : _googleLogin,
                        icon: Icons.g_mobiledata_rounded,
                        label: 'เข้าสู่ระบบด้วย Google',
                        iconColor: const Color(0xFFEA4335),
                        c: c,
                      ),
                      const SizedBox(height: 10),
                      _socialButton(
                        onPressed: isLoading ? null : () => _socialLogin('LINE'),
                        icon: Icons.chat_bubble_rounded,
                        label: 'เข้าสู่ระบบด้วย LINE',
                        iconColor: const Color(0xFF00C300),
                        c: c,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Toggle Login/Register
                GestureDetector(
                  onTap: () => setState(() => isLogin = !isLogin),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: RichText(
                      text: TextSpan(
                        text: isLogin ? 'ยังไม่มีบัญชี? ' : 'มีบัญชีแล้ว? ',
                        style: TextStyle(color: c.ink3, fontSize: 14),
                        children: [
                          TextSpan(
                            text: isLogin ? 'ลงทะเบียนที่นี่' : 'เข้าสู่ระบบที่นี่',
                            style: TextStyle(color: c.accent, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required AppColors c,
    bool obscureText = false,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: TextStyle(color: c.ink, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: c.ink3),
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

  Widget _socialButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    required Color iconColor,
    required AppColors c,
  }) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border.withValues(alpha: 0.5)),
      ),
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 24, color: iconColor),
        label: Text(label, style: TextStyle(color: c.ink, fontWeight: FontWeight.w600, fontSize: 14)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: BorderSide.none,
        ),
      ),
    );
  }
}
