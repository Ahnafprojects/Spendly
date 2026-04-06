import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/widgets/spendly_brand.dart';
import '../../../shared/widgets/app_notice.dart';
import '../auth_notifier.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with SingleTickerProviderStateMixin {
  bool _isLogin = true;
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  late AnimationController _bgCtrl;
  late Animation<double> _bgAnim;

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
    _bgAnim = CurvedAnimation(parent: _bgCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _navigateAfterLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final onboardingVal = prefs.getBool('onboarding_completed');
    if (!mounted) return;
    context.goNamed(onboardingVal == false ? 'onboarding' : 'dashboard');
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (_isLogin) {
      await ref.read(authNotifierProvider.notifier).signIn(email, password);
      return;
    }

    await ref
        .read(authNotifierProvider.notifier)
        .signUp(email, password);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<void>>(authNotifierProvider, (previous, next) {
      next.when(
        data: (_) async {
          if (!mounted) return;
          final hasSession =
              Supabase.instance.client.auth.currentSession != null;
          if (hasSession) {
            unawaited(_navigateAfterLogin());
            return;
          }
          if (!_isLogin) {
            AppNotice.success(
              context,
              'Registrasi berhasil. Cek email untuk verifikasi, lalu login.',
            );
            setState(() => _isLogin = true);
            return;
          }
          AppNotice.warning(
            context,
            'Login belum aktif. Pastikan email sudah diverifikasi.',
          );
        },
        error: (error, _) {
          String message = 'Terjadi kesalahan';
          if (error is AuthException) message = error.message;
          AppNotice.error(context, message);
        },
        loading: () {},
      );
    });

    final isLoading = ref.watch(authNotifierProvider).isLoading;

    return AnimatedBuilder(
      animation: _bgAnim,
      builder: (_, child) => _buildBackground(child!, isLoading),
      child: _buildContent(isLoading),
    );
  }

  Widget _buildBackground(Widget child, bool isLoading) {
    final t = _bgAnim.value;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(-0.5 + 0.3 * t, -1.0),
            end: Alignment(0.5 - 0.3 * t, 1.0),
            colors: [
              Color.lerp(const Color(0xFF060C1E), const Color(0xFF09152F), t)!,
              Color.lerp(const Color(0xFF0A1628), const Color(0xFF050A18), t)!,
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -80 + 30 * t,
              right: -80,
              child: _blob(320, const Color(0xFF2E90FA), 0.10 + 0.05 * t),
            ),
            Positioned(
              bottom: 40 + 35 * t,
              left: -100,
              child: _blob(380, const Color(0xFF00C2A8), 0.07 + 0.04 * t),
            ),
            Positioned(
              top: MediaQuery.of(context).size.height * 0.4 - 15 * t,
              right: 20,
              child: _blob(110, const Color(0xFF7C3AED), 0.06 + 0.03 * t),
            ),
            child,
          ],
        ),
      ),
    );
  }

  Widget _blob(double size, Color color, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: opacity), Colors.transparent],
          stops: const [0.0, 1.0],
        ),
      ),
    );
  }

  Widget _buildContent(bool isLoading) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 56),

            // Brand mark
            const SpendlyBrandMark(size: 76),
            const SizedBox(height: 16),
            const Text(
              'Spendly',
              style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Text(
                _isLogin
                    ? 'Selamat datang kembali'
                    : 'Mulai kelola keuanganmu',
                key: ValueKey(_isLogin),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),

            const SizedBox(height: 44),

            // Tab switcher
            Container(
              height: 50,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.09),
                ),
              ),
              child: Row(
                children: [
                  _buildTabButton('Masuk', true),
                  _buildTabButton('Daftar', false),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Form fields
            Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildField(
                    controller: _emailController,
                    hint: 'Email',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Email wajib diisi';
                      if (!v.contains('@')) return 'Format email tidak valid';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  _buildField(
                    controller: _passwordController,
                    hint: 'Kata Sandi',
                    icon: Icons.lock_outline_rounded,
                    obscure: _obscurePassword,
                    onToggle: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Password wajib diisi';
                      if (v.length < 8) {
                        return 'Password minimal 8 karakter';
                      }
                      return null;
                    },
                  ),
                  if (!_isLogin) ...[
                    const SizedBox(height: 14),
                    _buildField(
                      controller: _confirmPasswordController,
                      hint: 'Konfirmasi Kata Sandi',
                      icon: Icons.lock_reset_outlined,
                      obscure: _obscureConfirmPassword,
                      onToggle: () => setState(
                        () =>
                            _obscureConfirmPassword = !_obscureConfirmPassword,
                      ),
                      validator: (v) => v != _passwordController.text
                          ? 'Password tidak cocok'
                          : null,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 32),

            // CTA button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2E90FA), Color(0xFF00C2A8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2E90FA).withValues(alpha: 0.38),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          _isLogin ? 'Masuk' : 'Buat Akun',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                ),
              ),
            ),

            const SizedBox(height: 36),
            Text(
              'Dengan melanjutkan, kamu menyetujui\nsyarat penggunaan Spendly.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.25),
                fontSize: 12,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String label, bool isLoginTab) {
    final isSelected = _isLogin == isLoginTab;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _isLogin = isLoginTab),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          height: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            gradient: isSelected
                ? const LinearGradient(
                    colors: [Color(0xFF2E90FA), Color(0xFF1A79E5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF2E90FA).withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.42),
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    VoidCallback? onToggle,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization capitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      textCapitalization: capitalization,
      validator: validator,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.w400,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.32),
          fontSize: 15,
        ),
        prefixIcon: Icon(
          icon,
          color: Colors.white.withValues(alpha: 0.38),
          size: 20,
        ),
        suffixIcon: onToggle == null
            ? null
            : IconButton(
                onPressed: onToggle,
                icon: Icon(
                  obscure
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: Colors.white.withValues(alpha: 0.38),
                  size: 20,
                ),
              ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.07),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF2E90FA), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.redAccent.withValues(alpha: 0.7)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 12),
      ),
    );
  }
}
