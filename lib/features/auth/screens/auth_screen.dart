import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/widgets/spendly_brand.dart';
import '../../../shared/widgets/app_notice.dart';
import '../auth_notifier.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool _isLogin = true; // Mengatur state tab (Login / Register)
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Fungsi untuk submit form
  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      if (_isLogin) {
        ref.read(authNotifierProvider.notifier).signIn(email, password);
      } else {
        ref.read(authNotifierProvider.notifier).signUp(email, password);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Mendengarkan perubahan state untuk menampilkan SnackBar Error atau Sukses Navigasi
    ref.listen<AsyncValue<void>>(authNotifierProvider, (previous, next) {
      next.when(
        data: (_) {
          if (!mounted) return;

          final hasSession =
              Supabase.instance.client.auth.currentSession != null;

          if (hasSession) {
            context.goNamed('dashboard');
            return;
          }

          // Register berhasil tapi email belum diverifikasi, jadi belum ada session.
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
        error: (error, stackTrace) {
          // Menampilkan pesan error dari Supabase
          String message = "Terjadi kesalahan";
          if (error is AuthException) {
            message = error.message;
          }
          AppNotice.error(context, message);
        },
        loading: () {}, // Tidak melakukan apa-apa saat loading di listener
      );
    });

    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF060A15) : const Color(0xFFF4F8FF);
    final card = isDark ? const Color(0xFF111A2E) : Colors.white;
    final title = isDark ? Colors.white : const Color(0xFF12213B);
    final muted = isDark ? Colors.white70 : const Color(0xFF53627E);
    final inputBg = isDark ? const Color(0xFF1A2741) : const Color(0xFFF3F7FF);
    final inputBorder = isDark
        ? const Color(0xFF2A3A5C)
        : const Color(0xFFD4E1F8);

    return Scaffold(
      backgroundColor: bg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SpendlyBrandMark(size: 78),
              const SizedBox(height: 14),
              Text(
                _isLogin ? 'Welcome Back' : 'Create Your Account',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: title,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _isLogin
                    ? 'Kelola keuangan kamu dengan cepat.'
                    : 'Mulai perjalanan finansial yang lebih rapi.',
                style: TextStyle(color: muted, fontSize: 13),
              ),
              const SizedBox(height: 28),

              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark ? Colors.white12 : const Color(0xFFD9E5FA),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(
                        0xFF2E90FA,
                      ).withValues(alpha: isDark ? 0.18 : 0.08),
                      blurRadius: 30,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Toggle Tab Login / Register
                      Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1A2741)
                              : const Color(0xFFEAF1FF),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildTabButton(
                                'Login',
                                true,
                                isDark: isDark,
                              ),
                            ),
                            Expanded(
                              child: _buildTabButton(
                                'Register',
                                false,
                                isDark: isDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Field Email
                      _buildTextField(
                        controller: _emailController,
                        hintText: 'Email',
                        icon: Icons.email_outlined,
                        isDark: isDark,
                        inputBg: inputBg,
                        inputBorder: inputBorder,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Email wajib diisi';
                          }
                          if (!value.contains('@')) {
                            return 'Format email tidak valid';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Field Password
                      _buildTextField(
                        controller: _passwordController,
                        hintText: 'Password',
                        icon: Icons.lock_outline,
                        obscureText: _obscurePassword,
                        onToggleObscure: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                        isDark: isDark,
                        inputBg: inputBg,
                        inputBorder: inputBorder,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Password wajib diisi';
                          }
                          if (value.length < 8) {
                            return 'Password minimal 8 karakter';
                          }
                          return null;
                        },
                      ),

                      // Field Confirm Password (Hanya muncul saat Register)
                      if (!_isLogin) ...[
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _confirmPasswordController,
                          hintText: 'Konfirmasi Password',
                          icon: Icons.lock_reset_outlined,
                          obscureText: _obscureConfirmPassword,
                          onToggleObscure: () {
                            setState(
                              () => _obscureConfirmPassword =
                                  !_obscureConfirmPassword,
                            );
                          },
                          isDark: isDark,
                          inputBg: inputBg,
                          inputBorder: inputBorder,
                          validator: (value) {
                            if (value != _passwordController.text) {
                              return 'Password tidak cocok';
                            }
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: 32),

                      Container(
                        width: double.infinity,
                        height: 52,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2E90FA), Color(0xFF00C2A8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _submitForm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors
                                .transparent, // Transparan agar gradient terlihat
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : Text(
                                  _isLogin ? 'Masuk' : 'Daftar',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget custom untuk Tab Switch
  Widget _buildTabButton(
    String title,
    bool isLoginTab, {
    required bool isDark,
  }) {
    final isSelected = _isLogin == isLoginTab;
    return GestureDetector(
      onTap: () => setState(() => _isLogin = isLoginTab),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2E90FA) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white60 : const Color(0xFF5A6884)),
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  // Widget custom untuk TextField
  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    required bool isDark,
    required Color inputBg,
    required Color inputBorder,
    bool obscureText = false,
    VoidCallback? onToggleObscure,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1A1E2A)),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: isDark ? Colors.white38 : const Color(0xFF8F9CB7),
        ),
        prefixIcon: Icon(
          icon,
          color: isDark ? Colors.white54 : const Color(0xFF72809E),
        ),
        suffixIcon: onToggleObscure == null
            ? null
            : IconButton(
                onPressed: onToggleObscure,
                icon: Icon(
                  obscureText
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: isDark ? Colors.white54 : const Color(0xFF72809E),
                ),
              ),
        filled: true,
        fillColor: inputBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2E90FA)),
        ),
        errorStyle: const TextStyle(color: Colors.redAccent),
      ),
    );
  }
}
