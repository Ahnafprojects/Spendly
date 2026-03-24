import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/services/app_text.dart';
import '../../../shared/services/currency_settings.dart';
import '../../../shared/services/language_settings.dart';
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
  String _registerCurrencyCode = CurrencySettings.current.code;
  String _registerLanguageCode = LanguageSettings.current.code;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  String _t(String id, String en) => AppText.t(id: id, en: en);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Fungsi untuk submit form
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (_isLogin) {
      await ref.read(authNotifierProvider.notifier).signIn(email, password);
      return;
    }

    await CurrencySettings.setCurrencyCode(_registerCurrencyCode);
    await ref
        .read(appLanguageProvider.notifier)
        .setLanguage(_registerLanguageCode);
    await ref.read(authNotifierProvider.notifier).signUp(email, password);
  }

  Future<void> _pickRegisterCurrency() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: CurrencySettings.options.map((option) {
              final active = option.code == _registerCurrencyCode;
              return ListTile(
                title: Text('${option.code} (${option.symbol.trim()})'),
                subtitle: Text(option.label),
                trailing: active
                    ? const Icon(Icons.check_circle, color: Color(0xFF2E90FA))
                    : null,
                onTap: () => Navigator.pop(context, option.code),
              );
            }).toList(),
          ),
        );
      },
    );

    if (!mounted || selected == null) return;
    setState(() => _registerCurrencyCode = selected);
  }

  Future<void> _pickRegisterLanguage() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: LanguageSettings.options.map((option) {
              final active = option.code == _registerLanguageCode;
              final cc = option.locale.countryCode;
              final localeText = cc == null
                  ? option.locale.languageCode
                  : '${option.locale.languageCode}_$cc';
              return ListTile(
                title: Text(option.label),
                subtitle: Text(localeText),
                trailing: active
                    ? const Icon(Icons.check_circle, color: Color(0xFF2E90FA))
                    : null,
                onTap: () => Navigator.pop(context, option.code),
              );
            }).toList(),
          ),
        );
      },
    );

    if (!mounted || selected == null) return;
    setState(() => _registerLanguageCode = selected);
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
              _t(
                'Registrasi berhasil. Cek email untuk verifikasi, lalu login.',
                'Registration successful. Check your email for verification, then log in.',
              ),
            );
            setState(() => _isLogin = true);
            return;
          }

          AppNotice.warning(
            context,
            _t(
              'Login belum aktif. Pastikan email sudah diverifikasi.',
              'Login is not active yet. Make sure your email is verified.',
            ),
          );
        },
        error: (error, stackTrace) {
          // Menampilkan pesan error dari Supabase
          String message = _t('Terjadi kesalahan', 'Something went wrong');
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
                _isLogin
                    ? _t('Selamat Datang Kembali', 'Welcome Back')
                    : _t('Buat Akun Anda', 'Create Your Account'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: title,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _isLogin
                    ? _t(
                        'Kelola keuangan kamu dengan cepat.',
                        'Manage your finances faster.',
                      )
                    : _t(
                        'Mulai perjalanan finansial yang lebih rapi.',
                        'Start your cleaner financial journey.',
                      ),
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
                                _t('Masuk', 'Login'),
                                true,
                                isDark: isDark,
                              ),
                            ),
                            Expanded(
                              child: _buildTabButton(
                                _t('Daftar', 'Register'),
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
                            return _t('Email wajib diisi', 'Email is required');
                          }
                          if (!value.contains('@')) {
                            return _t(
                              'Format email tidak valid',
                              'Invalid email format',
                            );
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Field Password
                      _buildTextField(
                        controller: _passwordController,
                        hintText: _t('Kata Sandi', 'Password'),
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
                            return _t(
                              'Password wajib diisi',
                              'Password is required',
                            );
                          }
                          if (value.length < 8) {
                            return _t(
                              'Password minimal 8 karakter',
                              'Password must be at least 8 characters',
                            );
                          }
                          return null;
                        },
                      ),

                      // Field Confirm Password (Hanya muncul saat Register)
                      if (!_isLogin) ...[
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _confirmPasswordController,
                          hintText: _t(
                            'Konfirmasi Kata Sandi',
                            'Confirm Password',
                          ),
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
                              return _t(
                                'Password tidak cocok',
                                'Password does not match',
                              );
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildSelectTile(
                          icon: Icons.language_rounded,
                          label: _t('Bahasa', 'Language'),
                          value:
                              LanguageSettings.byCode(
                                _registerLanguageCode,
                              )?.label ??
                              _registerLanguageCode.toUpperCase(),
                          isDark: isDark,
                          inputBg: inputBg,
                          inputBorder: inputBorder,
                          onTap: _pickRegisterLanguage,
                        ),
                        const SizedBox(height: 12),
                        _buildSelectTile(
                          icon: Icons.attach_money_rounded,
                          label: _t('Mata Uang', 'Currency'),
                          value: _registerCurrencyCode,
                          isDark: isDark,
                          inputBg: inputBg,
                          inputBorder: inputBorder,
                          onTap: _pickRegisterCurrency,
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
                                  _isLogin
                                      ? _t('Masuk', 'Sign In')
                                      : _t('Daftar', 'Sign Up'),
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
      onTap: () => setState(() {
        _isLogin = isLoginTab;
        if (!_isLogin) {
          _registerCurrencyCode = CurrencySettings.current.code;
          _registerLanguageCode = LanguageSettings.current.code;
        }
      }),
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

  Widget _buildSelectTile({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
    required Color inputBg,
    required Color inputBorder,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: inputBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: inputBorder),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDark ? Colors.white54 : const Color(0xFF72809E),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: isDark ? Colors.white54 : const Color(0xFF72809E),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF1A1E2A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.expand_more_rounded,
              color: isDark ? Colors.white54 : const Color(0xFF72809E),
            ),
          ],
        ),
      ),
    );
  }
}
